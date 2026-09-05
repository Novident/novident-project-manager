use serde::*;
use std::cmp::min;
use unicode_segmentation::UnicodeSegmentation;

use crate::api::text::attributes::*;
use crate::api::text::diff::SLICE_ATTRIBUTES;
use crate::api::text::op_iterator::*;

pub const MAX_INT: usize = 9007199254740991;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TextOperation {
    Insert {
        insert: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        attributes: Option<Attributes>,
    },
    Retain {
        retain: usize,
        #[serde(skip_serializing_if = "Option::is_none")]
        attributes: Option<Attributes>,
    },
    Delete {
        delete: usize,
    },
}

impl TextOperation {
    pub fn length(&self) -> usize {
        match self {
            TextOperation::Insert { insert, .. } => insert.chars().count(), // Use chars() to count the characters (runes)
            TextOperation::Retain { retain, .. } => *retain,
            TextOperation::Delete { delete, .. } => *delete,
        }
    }

    pub fn is_empty(&self) -> bool {
        self.length() == 0
    }

    pub fn attributes(&self) -> Option<Attributes> {
        match self {
            TextOperation::Insert { attributes, .. } => attributes.clone(),
            TextOperation::Retain { attributes, .. } => attributes.clone(),
            TextOperation::Delete { .. } => None,
        }
    }

    pub fn data(&self) -> Option<String> {
        match self {
            TextOperation::Insert { insert, .. } => Some(insert.clone()),
            _ => None,
        }
    }
}

impl PartialEq for TextOperation {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (
                TextOperation::Insert {
                    insert: i1,
                    attributes: a1,
                },
                TextOperation::Insert {
                    insert: i2,
                    attributes: a2,
                },
            ) => i1 == i2 && a1 == a2,
            (
                TextOperation::Retain {
                    retain: r1,
                    attributes: a1,
                },
                TextOperation::Retain {
                    retain: r2,
                    attributes: a2,
                },
            ) => r1 == r2 && a1 == a2,
            (TextOperation::Delete { delete: d1 }, TextOperation::Delete { delete: d2 }) => {
                d1 == d2
            }
            _ => false,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct Delta {
    pub operations: Vec<TextOperation>,
    plain_text: Option<String>,
}

impl PartialEq for Delta {
    fn eq(&self, other: &Self) -> bool {
        self.operations == other.operations
    }
}

impl Delta {
    pub fn new() -> Self {
        Self {
            operations: Vec::new(),
            plain_text: None,
        }
    }

    pub fn from_operations(operations: Vec<TextOperation>) -> Self {
        Self {
            operations,
            plain_text: None,
        }
    }

    pub fn from_json(json: &serde_json::Value) -> Self {
        let mut delta = Delta::new();
        if let serde_json::Value::Array(arr) = json {
            for val in arr {
                if let Ok(op) = serde_json::from_value::<TextOperation>(val.clone()) {
                    delta.add(op);
                }
            }
        }
        delta
    }

    pub fn to_json(&self) -> serde_json::Value {
        serde_json::to_value(&self.operations).unwrap_or(serde_json::Value::Null)
    }

    pub fn is_not_empty(&self) -> bool {
        !self.operations.is_empty()
    }

    pub fn is_empty(&self) -> bool {
        self.operations.is_empty()
    }

    pub fn length(&self) -> usize {
        self.operations.iter().map(|op| op.length()).sum()
    }

    pub fn add_all(&mut self, operations: impl IntoIterator<Item = TextOperation>) {
        for op in operations {
            self.add(op);
        }
    }

    pub fn add(&mut self, operation: TextOperation) {
        if operation.is_empty() {
            return;
        }
        self.plain_text = None;

        if let Some(last_op) = self.operations.last_mut() {
            match (last_op, &operation) {
                // Merge Deletes
                (TextOperation::Delete { delete: d1 }, TextOperation::Delete { delete: d2 }) => {
                    *d1 += d2;
                    return;
                }
                // Reorder Delete -> Insert to Insert -> Delete
                (TextOperation::Delete { .. }, TextOperation::Insert { .. }) => {
                    let delete_op = self.operations.pop().unwrap();
                    self.operations.push(operation);
                    self.operations.push(delete_op);
                    return;
                }
                _ => {}
            }

            // Merge if the attributes are equal
            let last_op_ref = self.operations.last_mut().unwrap(); // Re-borrow
            if last_op_ref.attributes() == operation.attributes() {
                match (last_op_ref, operation.clone()) {
                    (
                        TextOperation::Insert { insert: i1, .. },
                        TextOperation::Insert { insert: i2, .. },
                    ) => {
                        i1.push_str(&i2);
                        return;
                    }
                    (
                        TextOperation::Retain { retain: r1, .. },
                        TextOperation::Retain { retain: r2, .. },
                    ) => {
                        *r1 += r2;
                        return;
                    }
                    _ => {}
                }
            }
        }

        self.operations.push(operation);
    }

    pub fn insert(&mut self, text: String, attributes: Option<Attributes>) {
        self.add(TextOperation::Insert {
            insert: text,
            attributes,
        });
    }

    pub fn retain(&mut self, length: usize, attributes: Option<Attributes>) {
        self.add(TextOperation::Retain {
            retain: length,
            attributes,
        });
    }

    pub fn delete(&mut self, length: usize) {
        self.add(TextOperation::Delete { delete: length });
    }

    pub fn slice(&self, start: usize, end: Option<usize>) -> Delta {
        let mut result = Delta::new();
        let mut iterator = OpIterator::new(&self.operations);
        let mut index = 0;

        while (end.is_none() || index < end.unwrap()) && iterator.has_next() {
            let next_op;
            if index < start {
                next_op = iterator.next(Some(start - index));
            } else {
                let take_len = end.map(|e| e - index);
                next_op = iterator.next(take_len);
                result.add(next_op.clone());
            }
            index += next_op.length();
        }

        result
    }

    pub fn compose(&self, other: &Delta) -> Delta {
        let mut this_iter = OpIterator::new(&self.operations);
        let mut other_iter = OpIterator::new(&other.operations);
        let mut operations = Vec::new();

        if let Some(TextOperation::Retain {
            retain,
            attributes: None,
        }) = other_iter.peek()
        {
            let mut first_left: usize = *retain;
            while let Some(TextOperation::Insert { .. }) = this_iter.peek() {
                if this_iter.peek_length() <= first_left {
                    first_left -= this_iter.peek_length();
                    operations.push(this_iter.next(None));
                } else {
                    break;
                }
            }
            if retain - first_left > 0 {
                other_iter.next(Some(retain - first_left));
            }
        }

        let mut delta = Delta::from_operations(operations);

        while this_iter.has_next() || other_iter.has_next() {
            if let Some(TextOperation::Insert { .. }) = other_iter.peek() {
                delta.add(other_iter.next(None));
            } else if let Some(TextOperation::Delete { .. }) = this_iter.peek() {
                delta.add(this_iter.next(None));
            } else {
                let length = min(this_iter.peek_length(), other_iter.peek_length());
                let this_op = this_iter.next(Some(length));
                let other_op = other_iter.next(Some(length));

                let is_retain = matches!(this_op, TextOperation::Retain { .. });
                let attributes =
                    compose_attributes(this_op.attributes(), other_op.attributes(), is_retain);

                if let TextOperation::Retain {
                    retain: other_retain,
                    ..
                } = other_op
                {
                    if other_retain > 0 {
                        let mut new_op = None;
                        match this_op {
                            TextOperation::Retain { .. } => {
                                new_op = Some(TextOperation::Retain {
                                    retain: length,
                                    attributes,
                                });
                            }
                            TextOperation::Insert { insert, .. } => {
                                new_op = Some(TextOperation::Insert { insert, attributes });
                            }
                            _ => {}
                        }

                        if let Some(op) = new_op.clone() {
                            delta.add(op);
                        }

                        if !other_iter.has_next()
                            && delta.is_not_empty()
                            && delta.operations.last() == new_op.as_ref()
                        {
                            let mut rest_delta = Delta::from_operations(this_iter.rest());
                            let mut combined = delta.clone();
                            combined.operations.append(&mut rest_delta.operations);
                            combined.chop();
                            return combined;
                        }
                    }
                } else if let TextOperation::Delete { .. } = other_op
                    && matches!(this_op, TextOperation::Retain { .. })
                {
                    delta.add(other_op);
                }
            }
        }
        delta.chop();
        delta
    }

    pub fn diff(&self, other: &Delta) -> Delta {
        if self.operations == other.operations {
            return Delta::new();
        }

        let get_text = |delta: &Delta| -> String {
            delta
                .operations
                .iter()
                .map(|op| match op {
                    TextOperation::Insert { insert, .. } => insert.clone(),
                    _ => panic!("diff() called with non-insert operations"),
                })
                .collect()
        };

        let str_this = get_text(self);
        let str_other = get_text(other);

        let mut ret_delta = Delta::new();
        let chunks = dissimilar::diff(&str_this, &str_other);

        let mut this_iter = OpIterator::new(&self.operations);
        let mut other_iter = OpIterator::new(&other.operations);

        for chunk in chunks {
            match chunk {
                dissimilar::Chunk::Insert(text) => {
                    let mut length = text.chars().count();
                    while length > 0 {
                        let op_length = min(other_iter.peek_length(), length);
                        ret_delta.add(other_iter.next(Some(op_length)));
                        length -= op_length;
                    }
                }
                dissimilar::Chunk::Delete(text) => {
                    let mut length = text.chars().count();
                    while length > 0 {
                        let op_length = min(this_iter.peek_length(), length);
                        this_iter.next(Some(op_length));
                        ret_delta.delete(op_length);
                        length -= op_length;
                    }
                }
                dissimilar::Chunk::Equal(text) => {
                    let mut length = text.chars().count();
                    while length > 0 {
                        let op_length = min(
                            min(this_iter.peek_length(), other_iter.peek_length()),
                            length,
                        );
                        let this_op = this_iter.next(Some(op_length));
                        let other_op = other_iter.next(Some(op_length));

                        if this_op.data() == other_op.data() {
                            ret_delta.retain(
                                op_length,
                                diff_attributes(this_op.attributes(), other_op.attributes()),
                            );
                        } else {
                            ret_delta.add(other_op);
                            ret_delta.delete(op_length);
                        }
                        length -= op_length;
                    }
                }
            }
        }

        ret_delta.trim();
        ret_delta
    }

    pub fn trim(&mut self) {
        if !self.is_not_empty() {
            return;
        }
        if let Some(TextOperation::Retain { attributes, .. }) = self.operations.last()
            && (attributes.is_none() || attributes.as_ref().unwrap().is_empty())
        {
            self.operations.pop();
        }
    }

    pub fn chop(&mut self) {
        if self.is_empty() {
            return;
        }
        self.plain_text = None;
        if let Some(TextOperation::Retain { attributes, .. }) = self.operations.last()
            && (attributes.is_none() || attributes.as_ref().unwrap().is_empty())
        {
            self.operations.pop();
        }
    }

    pub fn invert(&self, base: &Delta) -> Delta {
        let mut inverted = Delta::new();
        let mut previous_value = 0;

        for op in &self.operations {
            match op {
                TextOperation::Insert { .. } => {
                    inverted.delete(op.length());
                }
                TextOperation::Retain {
                    attributes: None, ..
                } => {
                    inverted.retain(op.length(), None);
                    previous_value += op.length();
                }
                TextOperation::Delete { .. } | TextOperation::Retain { .. } => {
                    let length = op.length();
                    let slice = base.slice(previous_value, Some(previous_value + length));

                    for base_op in slice.operations {
                        if matches!(op, TextOperation::Delete { .. }) {
                            inverted.add(base_op.clone());
                        } else if let TextOperation::Retain {
                            attributes: Some(op_attrs),
                            ..
                        } = op
                        {
                            inverted.retain(
                                base_op.length(),
                                Some(invert_attributes(
                                    base_op.attributes(),
                                    Some(op_attrs.clone()),
                                )),
                            );
                        }
                    }
                    previous_value += length;
                }
            }
        }

        inverted.chop();
        inverted
    }

    pub fn prev_rune_position(&mut self, pos: usize) -> usize {
        if pos == 0 {
            return 0;
        }
        let content = self.to_plain_text();
        // (Grapheme clusters) equivalent to CharacterBoundary from `characters` library for Dart
        content
            .grapheme_indices(true)
            .rev()
            .find(|&(i, _)| i < pos)
            .map(|(i, _)| i)
            .unwrap_or(0)
    }

    pub fn next_rune_position(&mut self, pos: usize) -> usize {
        let content = self.to_plain_text();
        if pos >= content.len().saturating_sub(1) {
            return content.len();
        }
        content
            .grapheme_indices(true)
            .find(|&(i, _)| i > pos)
            .map(|(i, _)| i)
            .unwrap_or(content.len())
    }

    pub fn to_plain_text(&mut self) -> String {
        if self.plain_text.is_none() {
            let text = self
                .operations
                .iter()
                .filter_map(|op| {
                    if let TextOperation::Insert { insert, .. } = op {
                        Some(insert.as_str())
                    } else {
                        None
                    }
                })
                .collect::<String>();
            self.plain_text = Some(text);
        }
        self.plain_text.clone().unwrap()
    }

    pub fn slice_attributes(&self, index: i32) -> Option<Attributes> {
        unsafe { SLICE_ATTRIBUTES.and_then(|f| f(self, index)) }
    }
}

impl std::ops::Add for Delta {
    type Output = Delta;

    fn add(self, other: Delta) -> Delta {
        let mut operations = self.operations.clone();
        if !other.operations.is_empty() {
            operations.push(other.operations[0].clone());
            operations.extend(other.operations.into_iter().skip(1));
        }
        Delta::from_operations(operations)
    }
}
