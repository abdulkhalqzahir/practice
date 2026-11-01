#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  RightClick_ShiftEnter.ahk
;  کلیکی لای ڕاست => Shift+Enter  (و دەژمێردرێت لە task_counter.ahk)
;
;  سکریپتێکی AutoHotkey ی تر Shift+Enter ی ئەم سکریپتە نابینێت،
;  بۆیە دوای هەر کلیکێک ئاگاداری task_counter.ahk دەکاتەوە تا بیژمێرێت.
;  پێویستە task_counter.ahk یش کرابێتەوە (وەشانی 10 یان نوێتر).
;  لە task_counter.ahk دا کلیکی لای ڕاست ناچالاک بکە (F11) تا دووجار نەژمێردرێت.
; ============================================================

RButton:: {
    Send "+{Enter}"
    try {
        DetectHiddenWindows true
        PostMessage(0x5556, 0, 0, , "task_counter.ahk ahk_class AutoHotkey")
        DetectHiddenWindows false
    }
}

; ئەگەر دەتەوێت کلیکی لای ڕاستی ئاسایش کار بکات لەگەڵ Shift+Enter،
; هێڵەکانی سەرەوە بسڕەوە و ئەمەی خوارەوە بەکاربهێنە:
; ~RButton::Send "+{Enter}"

; Ctrl+Alt+F11 سکریپتەکە بە تەواوی دادەخات
; (F11 بۆ task_counter.ahk ماوەتەوە، بۆ ئەوەی هەردوو سکریپت پێکەوە نەکەونە ناکۆکی)
^!F11::ExitApp
