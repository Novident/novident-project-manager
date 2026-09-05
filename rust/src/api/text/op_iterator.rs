use crate::api::text::delta::*;

pub struct OpIterator<'a> {
    operations: &'a [TextOperation],
    index: usize,
    offset: usize,
}

impl<'a> OpIterator<'a> {
    pub fn new(operations: &'a [TextOperation]) -> Self {
        Self {
            operations,
            index: 0,
            offset: 0,
        }
    }

    pub fn has_next(&self) -> bool {
        self.peek_length() < MAX_INT
    }

    pub fn peek(&self) -> Option<&'a TextOperation> {
        self.operations.get(self.index)
    }

    pub fn peek_length(&self) -> usize {
        if let Some(op) = self.operations.get(self.index) {
            return op.length() - self.offset;
        }
        MAX_INT
    }

    pub fn next(&mut self, length: Option<usize>) -> TextOperation {
        let mut length = length.unwrap_or(MAX_INT);

        if self.index >= self.operations.len() {
            return TextOperation::Retain {
                retain: MAX_INT,
                attributes: None,
            };
        }

        let next_op = &self.operations[self.index];
        let offset = self.offset;
        let op_length = next_op.length();

        if length >= op_length - offset {
            length = op_length - offset;
            self.index += 1;
            self.offset = 0;
        } else {
            self.offset += length;
        }

        match next_op {
            TextOperation::Delete { .. } => TextOperation::Delete { delete: length },
            TextOperation::Retain { attributes, .. } => TextOperation::Retain {
                retain: length,
                attributes: attributes.clone(),
            },
            TextOperation::Insert { insert, attributes } => {
                // Safely handle char-based substrings instead of bytes
                let substring = insert.chars().skip(offset).take(length).collect();
                TextOperation::Insert {
                    insert: substring,
                    attributes: attributes.clone(),
                }
            }
        }
    }

    pub fn rest(&mut self) -> Vec<TextOperation> {
        if !self.has_next() {
            vec![]
        } else if self.offset == 0 {
            self.operations[self.index..].to_vec()
        } else {
            let offset = self.offset;
            let index = self.index;
            let next_op = self.next(None);
            let mut rest_ops = vec![next_op];
            rest_ops.extend_from_slice(&self.operations[self.index..]);

            // Restore the state
            self.offset = offset;
            self.index = index;

            rest_ops
        }
    }
}
