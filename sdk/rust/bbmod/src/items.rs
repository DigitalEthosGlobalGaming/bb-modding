//! Offline English item catalog extracted from CUSA03173 1.09.
//! Exact IDs only: no guessed upgrade normalization. A catalog row is not proof
//! that an item is obtainable or safe to grant. Unknown IDs return None.
//! Inventory entries must have inventory::ID_RESOLVED before looking up their ID.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Category { Weapon, Protector, Accessory, Goods }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NameStatus { Named, Missing, Placeholder }

#[derive(Debug, Clone, Copy)]
pub struct Item {
    pub key: &'static str,
    pub name: Option<&'static str>,
    pub category: Category,
    pub param_id: u32,
    pub encoded_item_id: u32,
    pub name_status: NameStatus,
}

/// Portable mapping, available without a runtime file read or JSON dependency.
pub const JSON: &str = include_str!("../data/items.json");
include!("items_generated.rs");

/// Look up an exact snake_case key, e.g. `saw_cleaver` or `saw_cleaver_plus_1`.
pub fn by_key(key: &str) -> Option<&'static Item> {
    ITEMS.binary_search_by_key(&key, |item| item.key).ok().map(|i| &ITEMS[i])
}

/// Look up a category-encoded item ID (not an inventory runtime reference).
pub fn by_id(encoded_item_id: u32) -> Option<&'static Item> {
    ID_INDEX.binary_search_by_key(&encoded_item_id, |i| ITEMS[*i].encoded_item_id)
        .ok().map(|i| &ITEMS[ID_INDEX[i]])
}

/// Encode an exact parameter ID with an explicit category. Never use this for
/// an opaque inventory reference or an attack behavior ID.
pub fn encoded_id(category:Category,param_id:u32)->Option<u32>{
    if param_id>=0x10000000{return None;}
    let mask=match category{Category::Weapon=>0,Category::Protector=>0x10000000,Category::Accessory=>0x20000000,Category::Goods=>0x40000000};
    Some(mask|param_id)
}
pub fn by_param_id(category:Category,param_id:u32)->Option<&'static Item>{by_id(encoded_id(category,param_id)?)}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn known_items_and_exact_upgrades() {
        assert_eq!(by_key("saw_cleaver").unwrap().encoded_item_id, 7_000_000);
        assert_eq!(by_id(ids::SAW_CLEAVER).unwrap().name, Some("Saw Cleaver"));
        assert_eq!(by_key("saw_cleaver_plus_1").unwrap().encoded_item_id, 7_000_100);
        assert_eq!(by_key("blood_vial").unwrap().encoded_item_id, 0x400003E8);
        assert!(by_id(0xFFFFFFFF).is_none());
        assert!(by_id(0x300003E8).is_none());
        assert!(by_key("not_an_item").is_none());
        assert_eq!(by_param_id(Category::Goods,1000).unwrap().name,Some("Blood Vial"));
        assert!(by_param_id(Category::Goods,0x400003e8).is_none());
    }
    #[test]
    fn indexes_are_unique_sorted_and_roundtrip_every_row() {
        assert_eq!(ITEMS.len(), ID_INDEX.len());
        assert!(ITEMS.windows(2).all(|w| w[0].key < w[1].key));
        assert!(ID_INDEX.windows(2).all(|w| ITEMS[w[0]].encoded_item_id < ITEMS[w[1]].encoded_item_id));
        for item in ITEMS {
            assert_eq!(by_id(item.encoded_item_id).unwrap().key, item.key);
            assert_eq!(by_key(item.key).unwrap().encoded_item_id, item.encoded_item_id);
        }
    }
}
