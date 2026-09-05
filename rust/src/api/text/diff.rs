use crate::api::text::{attributes::*, delta::*};

pub type SliceAttributesFn = fn(&Delta, i32) -> Option<Attributes>;

pub fn default_slice_attributes(delta: &Delta, index: i32) -> Option<Attributes> {
    if index < 0 {
        return None;
    }

    let index = index as usize;

    if index == 0 && delta.is_not_empty() {
        let sliced = delta.slice(index, Some(index + 1));
        if let Some(op) = sliced.operations.first() {
            let attrs = op.attributes();
            attrs.as_ref()?;
            let attributes = attrs.unwrap();

            for key in attributes.keys() {
                if !DeltaAttributesKeys::SUPPORT_SLICED.contains(&key.as_str()) {
                    return None;
                }
            }
            return Some(attributes);
        }
        return None;
    }

    let prev_sliced = delta.slice(index - 1, Some(index));
    let prev_attrs = match prev_sliced.operations.first() {
        Some(op) => op.attributes(),
        None => return None,
    };

    let mut prev_attributes = prev_attrs?;

    let has_partial = prev_attributes
        .keys()
        .any(|k| DeltaAttributesKeys::PARTIAL_SLICED.contains(&k.as_str()));
    if !has_partial {
        return Some(prev_attributes);
    }

    let next_sliced = delta.slice(index, Some(index + 1));
    let next_attributes = next_sliced
        .operations
        .first()
        .and_then(|op| op.attributes());

    match next_attributes {
        None => {
            prev_attributes
                .retain(|k, _| !DeltaAttributesKeys::PARTIAL_SLICED.contains(&k.as_str()));
            Some(prev_attributes)
        }
        Some(next_attrs) => {
            let next_has_partial = next_attrs
                .keys()
                .any(|k| DeltaAttributesKeys::PARTIAL_SLICED.contains(&k.as_str()));
            if !next_has_partial {
                prev_attributes
                    .retain(|k, _| !DeltaAttributesKeys::PARTIAL_SLICED.contains(&k.as_str()));
            }
            Some(prev_attributes)
        }
    }
}

pub static mut SLICE_ATTRIBUTES: Option<SliceAttributesFn> = Some(default_slice_attributes);
