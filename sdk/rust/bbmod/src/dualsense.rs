//! SDL-proven DualSense effect builders. Raw effects require hardware validation.
use crate::{check, sys, Cx, Error, Result};
pub type PadInfo = sys::bbm_pad_info;
pub const HAS_TRIGGERS: u32 = 1;
pub const HAS_LIGHTBAR: u32 = 2;
pub const CAPTURED: u32 = 4;
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u32)]
pub enum Trigger {
    Left = 0,
    Right = 1,
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Effect(pub [u8; 11]);
pub fn off() -> Effect {
    let mut b = [0; 11];
    b[0] = 5;
    Effect(b)
}
pub fn resistance(start: u8, force: u8) -> Effect {
    let mut b = [0; 11];
    b[0] = 1;
    b[1] = start;
    b[2] = force;
    Effect(b)
}
/// Parameters are raw SDL reference bytes; their physical meaning is unverified.
pub fn resistance_vibration(a: u8, b: u8, c: u8) -> Effect {
    let mut out = [0; 11];
    out[..4].copy_from_slice(&[6, a, b, c]);
    Effect(out)
}
pub fn raw(bytes: [u8; 11]) -> Effect {
    Effect(bytes)
}
impl Cx {
    fn pad_api(&self) -> Result<&sys::bbm_host> {
        // Read the prefix before forming a reference to the extended table.
        let size = unsafe { core::ptr::addr_of!((*self.host).size).read() } as usize;
        if size >= core::mem::size_of::<sys::bbm_host>() {
            Ok(unsafe { &*self.host })
        } else {
            Err(Error::UNSUPPORTED)
        }
    }
    pub fn pad_info(&self) -> Result<PadInfo> {
        let h = self.pad_api()?;
        let mut out = PadInfo::default();
        check(unsafe { (h.pad_info)(self.me, &mut out) })?;
        Ok(out)
    }
    pub fn pad_trigger(&self, which: Trigger, effect: Effect) -> Result<()> {
        check(unsafe { (self.pad_api()?.pad_trigger)(self.me, which as u32, effect.0.as_ptr()) })
    }
    pub fn pad_release(&self, which: Trigger) -> Result<()> {
        check(unsafe { (self.pad_api()?.pad_release)(self.me, which as u32) })
    }
    pub fn pad_lightbar(&self, rgb: [u8; 3]) -> Result<()> {
        check(unsafe { (self.pad_api()?.pad_lightbar)(self.me, rgb[0], rgb[1], rgb[2]) })
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reference_bytes() {
        assert_eq!(off().0, [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        assert_eq!(resistance(0, 110).0, [1, 0, 110, 0, 0, 0, 0, 0, 0, 0, 0]);
        assert_eq!(
            resistance_vibration(15, 63, 128).0,
            [6, 15, 63, 128, 0, 0, 0, 0, 0, 0, 0]
        );
    }
    #[test]
    fn c_layout() {
        assert_eq!(std::mem::size_of::<PadInfo>(), 24);
    }
}
