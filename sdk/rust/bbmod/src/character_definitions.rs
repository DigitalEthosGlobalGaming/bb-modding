//! Offline NPC definitions. IDs are NpcParam row IDs, not entity/name IDs or
//! runtime handles. Several live characters can share a single definition.
pub use crate::items::NameStatus;
#[derive(Debug,Clone,Copy,PartialEq,Eq,PartialOrd,Ord,Hash)]
pub struct NpcParamId(pub u32);
#[derive(Debug,Clone,Copy)]
pub struct CharacterDefinition {
    pub id:NpcParamId,
    pub key:&'static str,
    pub name_id:i32,
    pub name:Option<&'static str>,
    /// Unavailable in the baseline NPC/name sources; no invented lore.
    pub description:Option<&'static str>,
    /// Internal development row name, often Japanese; not a localized display name.
    pub internal_name:Option<&'static str>,
    /// Community English row label, matched by exact ID and original Japanese text.
    /// May be a literal translation, NOT official localized NPC text.
    pub reference_name:Option<&'static str>,
    pub name_status:NameStatus,
    /// Raw baseline PARAM value, before runtime scaling/effects/overlays.
    pub base_health:u32,
    pub team_type:u8,
}
pub const JSON:&str=include_str!("../data/characters.json");
include!("character_definitions_generated.rs");
pub fn by_id(id:NpcParamId)->Option<&'static CharacterDefinition>{DEFINITIONS.binary_search_by_key(&id,|d|d.id).ok().map(|i|&DEFINITIONS[i])}
/// Numeric convenience lookup, explicitly using an NPC parameter row ID.
pub fn get_character_definition(npc_param_id:u32)->Option<&'static CharacterDefinition>{by_id(NpcParamId(npc_param_id))}
pub fn by_key(key:&str)->Option<&'static CharacterDefinition>{
    let d=get_character_definition(key.strip_prefix("bloodborne.npc_")?.parse().ok()?)?;
    (d.key==key).then_some(d)
}
/// A name ID is shared by variants; return all matches rather than an arbitrary row.
pub fn by_name_id(name_id:i32)->impl Iterator<Item=&'static CharacterDefinition>{
    let start=NAME_INDEX.partition_point(|i|DEFINITIONS[*i].name_id<name_id);
    NAME_INDEX[start..].iter().take_while(move|i|DEFINITIONS[**i].name_id==name_id).map(|i|&DEFINITIONS[*i])
}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn exact_ids_and_missing_text(){
        assert_eq!(get_character_definition(500000).unwrap().name,Some("Cleric Beast"));
        assert_eq!(by_key("bloodborne.npc_500000").unwrap().id,NpcParamId(500000));
        assert!(by_key("bloodborne.npc_0500000").is_none());
        assert_eq!(get_character_definition(271000).unwrap().name,Some("Father Gascoigne"));
        let unknown_name=get_character_definition(1000).unwrap();assert!(unknown_name.name.is_none());assert!(unknown_name.internal_name.is_some());assert!(unknown_name.description.is_none());
        assert!(get_character_definition(u32::MAX).is_none());assert!(get_character_definition(0x10014025).is_none());
        let ordinary=get_character_definition(112401).unwrap();assert!(ordinary.name.is_none());assert!(ordinary.reference_name.unwrap().starts_with("Drowned Beast"));
    }
    #[test]fn index_roundtrip_and_shared_name_ids(){
        assert!(DEFINITIONS.windows(2).all(|d|d[0].id<d[1].id));
        assert!(by_name_id(500000).count()>1);
        for d in DEFINITIONS{assert_eq!(by_id(d.id).unwrap().key,d.key);assert!(by_name_id(d.name_id).any(|n|n.id==d.id));}
    }
}
