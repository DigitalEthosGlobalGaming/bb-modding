use crate::sys;
use std::ffi::CString;

/// Widgets, valid only inside a panel's draw closure.
pub struct Ui {
    host: *const sys::bbm_host,
    me: sys::bbm_handle,
    cx: *const crate::Cx,
}

impl Ui {
    pub(crate) fn new(host: *const sys::bbm_host, me: sys::bbm_handle, cx: *const crate::Cx) -> Ui {
        Ui { host, me, cx }
    }
    /// The mod's `Cx`, to patch, read memory or log from a panel.
    pub fn cx(&self) -> &crate::Cx { unsafe { &*self.cx } }
    fn h(&self) -> &sys::bbm_host { unsafe { &*self.host } }
    fn c(s: &str) -> CString { CString::new(s.replace('\0', "")).unwrap_or_default() }

    pub fn text(&self, s: &str) { let c = Self::c(s); unsafe { (self.h().ui_text)(self.me, c.as_ptr()) } }
    pub fn button(&self, label: &str) -> bool {
        let c = Self::c(label);
        unsafe { (self.h().ui_button)(self.me, c.as_ptr()) != 0 }
    }
    pub fn checkbox(&self, label: &str, value: &mut bool) -> bool {
        let c = Self::c(label);
        let mut v = *value as i32;
        let changed = unsafe { (self.h().ui_checkbox)(self.me, c.as_ptr(), &mut v) != 0 };
        *value = v != 0;
        changed
    }
    pub fn slider_f32(&self, label: &str, value: &mut f32, min: f32, max: f32) -> bool {
        let c = Self::c(label);
        unsafe { (self.h().ui_slider_float)(self.me, c.as_ptr(), value, min, max) != 0 }
    }
    pub fn separator(&self) { unsafe { (self.h().ui_separator)(self.me) } }
    pub fn same_line(&self) { unsafe { (self.h().ui_same_line)(self.me) } }

    // ---- ABI 1.1 widgets (fall back gracefully on a 1.0 host) --------------

    pub fn slider_i32(&self, label: &str, value: &mut i32, min: i32, max: i32) -> bool {
        if !self.h().has_v1_1() { return false; }
        let c = Self::c(label);
        unsafe { (self.h().ui_slider_int)(self.me, c.as_ptr(), value, min, max) != 0 }
    }

    /// Single-line text box editing `value` (at most `cap - 1` bytes). True when edited.
    pub fn input_text(&self, label: &str, value: &mut String, cap: usize) -> bool {
        if !self.h().has_v1_1() { return false; }
        let c = Self::c(label);
        let mut buf = vec![0u8; cap.max(2)];
        let n = value.len().min(buf.len() - 1);
        buf[..n].copy_from_slice(&value.as_bytes()[..n]);
        let changed = unsafe { (self.h().ui_input_text)(self.me, c.as_ptr(), buf.as_mut_ptr().cast(), buf.len()) != 0 };
        if changed {
            let end = buf.iter().position(|&b| b == 0).unwrap_or(buf.len());
            *value = String::from_utf8_lossy(&buf[..end]).into_owned();
        }
        changed
    }

    /// A foldable section; draw its contents only when this returns true.
    pub fn collapsing_header(&self, label: &str) -> bool {
        if !self.h().has_v1_1() { return true; }
        let c = Self::c(label);
        unsafe { (self.h().ui_collapsing_header)(self.me, c.as_ptr()) != 0 }
    }

    /// Drop-down; `current` indexes `items`. True when the choice changed.
    pub fn combo(&self, label: &str, current: &mut usize, items: &[&str]) -> bool {
        if !self.h().has_v1_1() || items.is_empty() { return false; }
        let c = Self::c(label);
        let mut list = Vec::new();
        for it in items {
            list.extend(it.bytes().filter(|&b| b != 0));
            list.push(0);
        }
        list.push(0);
        let mut cur = (*current).min(items.len() - 1) as i32;
        let changed = unsafe { (self.h().ui_combo)(self.me, c.as_ptr(), &mut cur, list.as_ptr().cast()) != 0 };
        *current = cur.max(0) as usize;
        changed
    }

    /// Coloured text, RGBA in 0..1 (`[1.0, 0.4, 0.4, 1.0]` for a warning).
    pub fn text_colored(&self, rgba: [f32; 4], s: &str) {
        let c = Self::c(s);
        if self.h().has_v1_1() {
            unsafe { (self.h().ui_text_colored)(self.me, rgba[0], rgba[1], rgba[2], rgba[3], c.as_ptr()) }
        } else {
            unsafe { (self.h().ui_text)(self.me, c.as_ptr()) }
        }
    }
}
