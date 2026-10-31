#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  shift_enter_counter.ahk
;  - Shift+Enter ی کیبۆرد دەژمێرێت (تەنها لەسەر ماڵپەڕی xawan)
;  - هەر Shift+Enter ێک لەگەڵ «جۆری تاسک» تۆمار دەکرێت (ناوی تابەکە)
;  - Shift+Enter ی کلیکی ڕاست لەلایەن RightClick_ShiftEnter.ahk ەوە دەژمێردرێت
;  - دوای 10 کاتژمێر لە یەکەم Shift+Enter، ژمارەی «ئێستا» دەگەڕێتەوە سفر
;  - F2 (fn+F2)   = ژمارەی ئێستا + ئەمڕۆ بەپێی جۆر + مێژوو
;  - Ctrl+Alt+F1  = ناوی تابی ئێستا زیاد دەکات وەک «جۆری تاسک»
;  - Ctrl+Alt+F2  = پشکنین
;  - Ctrl+Alt+F3  = گۆڕینی ناو / کۆدی وێب
;  - Ctrl+Alt+F4  = پشکنینی ناردن (ئەنجامی ڕاستەوخۆ پیشان دەدات)
;  - Ctrl+Alt+F5  = سفرکردنەوەی هەموو ژمارەکانی ئەم کۆمپیوتەرە
;
;  ئەگەر تاب جۆرێکی دیاریکراوی نەبوو، ژمارەکە دەچێتە «گشتی».
;  بۆ ئەوەی هەر تاسکێک ناوی خۆی هەبێت: لەسەر تابەکە Ctrl+Alt+F1 بکە.
; ============================================================

global IniDir  := A_AppData "\ShiftEnterCounter"
DirCreate(IniDir)
global IniFile := IniDir "\shift_enter_count.ini"
global Browsers := "msedge.exe|chrome.exe|firefox.exe|brave.exe|opera.exe"
global ResetHours := 10
global DefaultKeywords := "xawan|خاوەن|خاوه‌ن|پلاتفۆرم|indexing"
global SendDays := 95          ; چەند ڕۆژی کۆتایی بنێردرێت بۆ Pantry

; ---------- ناوی جۆری تاسک پاک دەکاتەوە ----------
CleanTask(s) {
    s := Trim(s)
    s := RegExReplace(s, '[=|"\\\[\]\r\n]', "")
    return Trim(SubStr(s, 1, 40))
}

; جۆری تاسک = ئەو ناوەی لە تۆمارکردندا نووسراوە ("" = ئەم پەنجەرەیە ماڵپەڕەکە نییە)
SiteTask() {
    try {
        title := WinGetTitle("A")
        proc  := WinGetProcessName("A")
    } catch
        return ""
    if !InStr(Browsers, proc)
        return ""
    for k in StrSplit(IniRead(IniFile, "Settings", "Keywords", DefaultKeywords), "|") {
        k := Trim(k)
        if (k != "" && InStr(title, k))
            return TaskName != "" ? TaskName : "گشتی"
    }
    return ""
}

IsSite() {
    return SiteTask() != ""
}

; ئەگەر 10 کاتژمێر تێپەڕیبێت، ژمارەی کۆن دەچێتە مێژوو و ژمارەی نوێ سفر دەبێت
Rollover() {
    start := IniRead(IniFile, "Current", "Start", "")
    if (start = "")
        return
    if (DateDiff(A_Now, start, "Seconds") >= ResetHours * 3600) {
        cnt := Integer(IniRead(IniFile, "Current", "Count", "0"))
        if (cnt > 0)
            IniWrite(cnt, IniFile, "History", FormatTime(start, "yyyy-MM-dd HH:mm"))
        IniDelete(IniFile, "Current", "Start")
        IniDelete(IniFile, "Current", "Count")
    }
}

CountOne() {
    task := SiteTask()
    if (task = "")
        return
    Rollover()
    if (IniRead(IniFile, "Current", "Start", "") = "") {
        IniWrite(A_Now, IniFile, "Current", "Start")
        IniWrite(0, IniFile, "Current", "Count")
    }
    n := Integer(IniRead(IniFile, "Current", "Count", "0")) + 1
    IniWrite(n, IniFile, "Current", "Count")

    ; ژمارەی ڕۆژانە بەپێی جۆری تاسک (ئەمە دەنێردرێت بۆ ماڵپەڕ)
    key := FormatTime(, "yyyy-MM-dd") "|" task
    IniWrite(Integer(IniRead(IniFile, "Tasks", key, "0")) + 1, IniFile, "Tasks", key)
    SetTimer(FullSync, -4000)       ; 4 چرکە دوای کۆتایی Shift+Enter، دەنێرێت
}

; گواستنەوەی ژمارە کۆنەکان (ئەگەر فایلی کۆن لە تەنیشت سکریپتەکەیە)
if (!FileExist(IniFile) && FileExist(A_ScriptDir "\shift_enter_count.ini"))
    FileCopy(A_ScriptDir "\shift_enter_count.ini", IniFile)

; فایلی ini بە UTF-16 دروست دەبێت بۆ ئەوەی ناوی کوردی دروست بمێنێتەوە
if !FileExist(IniFile)
    FileAppend("[Settings]`n", IniFile, "UTF-16")

; ============ ژمارەی کۆنی ڕۆژانە (پێش ئەم وەشانە) ============
OldDays() {
    days := Map()
    try section := IniRead(IniFile, "History")
    catch
        section := ""
    for line in StrSplit(section, "`n", "`r") {
        p := StrSplit(line, "=")
        if (p.Length < 2 || StrLen(p[1]) < 10 || !IsInteger(p[2]))
            continue
        d := SubStr(p[1], 1, 10)
        days[d] := (days.Has(d) ? days[d] : 0) + Integer(p[2])
    }
    st := IniRead(IniFile, "Current", "Start", "")
    if (st != "") {
        d := SubStr(st, 1, 4) "-" SubStr(st, 5, 2) "-" SubStr(st, 7, 2)
        days[d] := (days.Has(d) ? days[d] : 0) + Integer(IniRead(IniFile, "Current", "Count", "0"))
    }
    return days
}

; یەکەمجار: ژمارە کۆنەکان دەگوازرێنەوە بۆ جۆری «پێشتر»
if (IniRead(IniFile, "Settings", "TasksMigrated", "") = "") {
    for d, n in OldDays() {
        if (n > 0)
            IniWrite(n, IniFile, "Tasks", d "|پێشتر")
    }
    IniWrite(1, IniFile, "Settings", "TasksMigrated")
}

; ============ تۆمارکردن + ناردنی ژمارەکان بۆ ماڵپەڕی بەڕێوەبەر (Pantry) ============
global PantryId := IniRead(IniFile, "Settings", "PantryId", "")
global PersonName := IniRead(IniFile, "Settings", "PersonName", "")
global TaskName := IniRead(IniFile, "Settings", "TaskName", "")
global Pending := ""

JName(s) {
    return StrReplace(StrReplace(s, '"', ""), Chr(92), "")
}

NowEpoch() {
    return DateDiff(A_NowUTC, "19700101", "Seconds")
}

Register() {
    global PantryId, PersonName, TaskName
    r := InputBox("ناوی خۆت بنووسە", "تۆمارکردن", , PersonName)
    if (r.Result != "OK" || Trim(r.Value) = "")
        return
    tk := InputBox("ناوی تاسک (جۆری کارەکەت) بنووسە", "تۆمارکردن", , TaskName)
    if (tk.Result != "OK" || CleanTask(tk.Value) = "")
        return
    c := InputBox("کۆدی وێب لێرە دابنێ (لە بەڕێوەبەرەکەت وەریبگرە)", "تۆمارکردن")
    if (c.Result != "OK")
        return
    code := Trim(c.Value)
    if (StrLen(code) < 20 || InStr(code, " ") || InStr(code, "/")) {
        MsgBox("کۆدەکە دروست نییە. بۆ دووبارە هەوڵدان Ctrl+Alt+F3 دابگرە.", "تۆمارکردن")
        return
    }
    oldName := PersonName
    oldId := PantryId
    PersonName := Trim(r.Value)
    TaskName := CleanTask(tk.Value)
    IniWrite(TaskName, IniFile, "Settings", "TaskName")
    PantryId := code
    IniWrite(PersonName, IniFile, "Settings", "PersonName")
    IniWrite(PantryId, IniFile, "Settings", "PantryId")
    IniWrite(NowEpoch(), IniFile, "Settings", "RegisteredAt")
    ; ناوی کۆن وەک ناچالاک دادەنرێت
    if (oldName != "" && (oldName != PersonName || oldId != PantryId))
        SendOffline(oldName, oldId)
    SetTimer(() => Sync(), -1000)
    MsgBox("تۆمار کرا ✔`nناو: " PersonName "`nتاسک: " TaskName, "تۆمارکردن")
}

; ڕۆژ -> (جۆری تاسک -> ژمارە)، تەنها ڕۆژانی کۆتایی
BuildDays() {
    days := Map()
    try section := IniRead(IniFile, "Tasks")
    catch
        section := ""
    cutoff := FormatTime(DateAdd(A_Now, -SendDays, "Days"), "yyyy-MM-dd")
    for line in StrSplit(section, "`n", "`r") {
        i := InStr(line, "=")
        if (i < 12)
            continue
        key := SubStr(line, 1, i - 1)
        v := SubStr(line, i + 1)
        d := SubStr(key, 1, 10)
        if (SubStr(key, 11, 1) != "|" || StrCompare(d, cutoff) < 0 || !IsInteger(v))
            continue
        if !days.Has(d)
            days[d] := Map()
        days[d][SubStr(key, 12)] := Integer(v)
    }
    return days
}

BuildBody(active := 1) {
    days := BuildDays()
    js := ""
    for d, tasks in days {
        tj := ""
        for t, n in tasks
            tj .= (tj = "" ? "" : ",") '"' t '":' n
        js .= (js = "" ? "" : ",") '"' d '":{' tj '}'
    }
    return '{"people":{"' JName(PersonName) '":{"seen":' NowEpoch() ',"active":' active ',"days":{' js '}}}}'
}

; ژمارەکانی ئەم کۆمپیوتەرە سفر دەکاتەوە (ناو و کۆد و تاسک دەمێنن)
ClearLocal() {
    IniDelete(IniFile, "Tasks")
    IniDelete(IniFile, "History")
    IniDelete(IniFile, "Current")
    IniWrite(1, IniFile, "Settings", "TasksMigrated")
}

; بەڕێوەبەر ئەم کەسەی سڕییەوە: ژمارەکان سفر، تۆمار دەسڕێتەوە و سکریپت دەوەستێت
RemoveSelf() {
    global PersonName, TaskName
    ClearLocal()
    IniDelete(IniFile, "Settings", "PersonName")
    IniDelete(IniFile, "Settings", "TaskName")
    IniDelete(IniFile, "Settings", "RegisteredAt")
    PersonName := ""
    TaskName := ""
    MsgBox("ئەم هەژمارە لەلایەن بەڕێوەبەرەوە لابرا. بۆ تۆمارکردنەوە سکریپتەکە دووبارە بکەرەوە.", "لابرا", "Iconi")
    ExitApp()
}

; ئەگەر بەڕێوەبەر لە داشبۆرد «سفرکردنەوەی داتا» ی کرد، ژمارەکانی ئێرەش خۆکار سفر دەکرێنەوە
CheckReset() {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(2000, 2000, 3000, 3000)
        req.Open("GET", "https://getpantry.cloud/apiv1/pantry/" PantryId "/basket/reset", false)
        req.Send()
        last := IniRead(IniFile, "Settings", "ResetId", "")
        ; ئەگەر بەڕێوەبەر ئەم کەسەی سڕیبێتەوە
        if (req.Status = 200 && PersonName != "" && RegExMatch(req.ResponseText, '\Q"' JName(PersonName) '"\E\s*:\s*(\d+)', &rm)) {
            if (Integer(rm[1]) > Integer(IniRead(IniFile, "Settings", "RegisteredAt", "0")) * 1000) {
                RemoveSelf()
                return
            }
        }
        if (req.Status = 200 && RegExMatch(req.ResponseText, '"id"\s*:\s*(\d+)', &m)) {
            rid := Integer(m[1])
            if (last = "")
                IniWrite(rid, IniFile, "Settings", "ResetId")        ; یەکەمجار: تەنها دەیزانین
            else if (rid > Integer(last)) {
                ClearLocal()
                IniWrite(rid, IniFile, "Settings", "ResetId")
            }
        } else if (last = "" && req.Status = 400) {
            IniWrite(0, IniFile, "Settings", "ResetId")
        }
    }
}

global Reqs := []
global LastCheck := 0

; full = هەموو داتا؛ نەخێر = تەنها نیشانەی «چالاکم» (سووک و خێرا)
Sync(full := true) {
    global Reqs, LastCheck
    if (PersonName = "" || PantryId = "")
        return
    if (full || A_TickCount - LastCheck > 55000) {
        LastCheck := A_TickCount
        CheckReset()
        if (PersonName = "")
            return
    }
    body := full ? BuildBody() : '{"people":{"' JName(PersonName) '":{"seen":' NowEpoch() ',"active":1}}}'
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(5000, 5000, 10000, 15000)
        req.Open("PUT", "https://getpantry.cloud/apiv1/pantry/" PantryId "/basket/shift", true)   ; true = ناسینکرۆن
        req.SetRequestHeader("Content-Type", "application/json")
        req.Send(body)
        Reqs.Push(req)
        if (Reqs.Length > 6)
            Reqs.RemoveAt(1)
    }
}

FullSync() {
    Sync(true)
}

; ناردنی ڕاستەوخۆ (بێ چاوەڕوانی) بۆ کاتی داخستن
SendNow(body, pid) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(3000, 3000, 5000, 5000)
        req.Open("PUT", "https://getpantry.cloud/apiv1/pantry/" pid "/basket/shift", false)
        req.SetRequestHeader("Content-Type", "application/json")
        req.Send(body)
    }
}

SendOffline(nm, pid) {
    if (nm = "" || pid = "")
        return
    SendNow('{"people":{"' JName(nm) '":{"seen":' NowEpoch() ',"active":0}}}', pid)
}

; کاتێک سکریپتەکە دادەخرێت، ماڵپەڕ دەزانێت کە ناچالاکە
ExitHandler(reason, code) {
    if (reason = "Reload" || reason = "Single")
        return                       ; سکریپتی نوێ شوێنی دەگرێتەوە، ناچالاک مەنێرە
    if (PersonName != "" && PantryId != "")
        SendNow(BuildBody(0), PantryId)
}
OnExit(ExitHandler)

SetTimer(Sync, 120000)                          ; هەر 2 خولەک: هەموو داتا
SetTimer(() => Sync(false), 30000)              ; هەر 30 چرکە: نیشانەی «چالاکم»
SetTimer(() => Sync(), -3000)                   ; یەکەم ناردن 3 چرکە دوای کردنەوە

if (PersonName = "" || PantryId = "" || TaskName = "")
    Register()

; Ctrl+Alt+F3 = گۆڕینی ناو یان کۆدی وێب
^!F3:: Register()

; ---------- پشکنینی ناردن: ڕاستەوخۆ دەنێرێت و ئەنجامەکەی پیشان دەدات ----------
^!F4:: {
    if (PersonName = "" || PantryId = "") {
        MsgBox("هێشتا تۆمار نەکراویت. Ctrl+Alt+F3 دابگرە.", "پشکنین")
        return
    }
    body := BuildBody()
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(8000, 8000, 15000, 20000)
        req.Open("PUT", "https://getpantry.cloud/apiv1/pantry/" PantryId "/basket/shift", false)
        req.SetRequestHeader("Content-Type", "application/json")
        req.Send(body)
        MsgBox("ئەنجام: " req.Status " " req.StatusText "`n`n" req.ResponseText "`n`nنێردرا:`n" body, "پشکنینی ناردن")
    } catch as e {
        MsgBox("هەڵە: " e.Message, "پشکنینی ناردن")
    }
}

; ---------- سفرکردنەوەی ژمارەکانی ئەم کۆمپیوتەرە ----------
^!F5:: {
    if (MsgBox("هەموو ژمارەکانی ئەم کۆمپیوتەرە سفر بکرێنەوە؟", "سفرکردنەوە", "YesNo Icon!") != "Yes")
        return
    ClearLocal()
    MsgBox("ژمارەکانی ئەم کۆمپیوتەرە سفر کرانەوە ✔", "سفرکردنەوە")
}

; ---------- Shift+Enter ی کیبۆرد ----------
~+Enter:: CountOne()

; ---------- پیشاندانی ژمارە ----------
$F2:: {
    Rollover()
    start := IniRead(IniFile, "Current", "Start", "")
    cur := (start = "") ? 0 : Integer(IniRead(IniFile, "Current", "Count", "0"))

    remain := "—"
    since := "—"
    if (start != "") {
        secs := ResetHours * 3600 - DateDiff(A_Now, start, "Seconds")
        remain := Format("{}:{:02} کاتژمێر", secs // 3600, Mod(secs, 3600) // 60)
        since := FormatTime(start, "yyyy-MM-dd HH:mm")
    }

    total := cur
    arr := []
    try section := IniRead(IniFile, "History")
    catch
        section := ""
    for line in StrSplit(section, "`n", "`r") {
        p := StrSplit(line, "=")
        if (p.Length < 2)
            continue
        total += Integer(p[2])
        arr.Push(p[1] "  →  " p[2])
    }

    lines := ""
    Loop Min(arr.Length, 15)
        lines .= arr[arr.Length - A_Index + 1] "`n"

    todayLines := ""
    allDays := BuildDays()
    td := FormatTime(, "yyyy-MM-dd")
    if allDays.Has(td) {
        for t, n in allDays[td]
            todayLines .= t "  →  " n "`n"
    }
    if (todayLines = "")
        todayLines := "—`n"

    MsgBox("ژمارەی ئێستا: " cur " جار Shift+Enter`n"
        . "دەستپێکرد: " since "`n"
        . "ماوە تا سفربوونەوە: " remain "`n`n"
        . "ئەمڕۆ بەپێی جۆری تاسک:`n" todayLines "`n"
        . "کۆی گشتی: " total "`n`n"
        . "ماوەکانی پێشوو:`n" lines, "ژمارەی Shift+Enter")
}

; ---------- زیادکردنی ناوی تاب (جۆری تاسک) ----------
^!F1:: {
    title := WinGetTitle("A")
    key := CleanTask(RegExReplace(title, "\s[-–—]\s.*$", ""))
    if (key = "") {
        MsgBox("ناوی تاب بەتاڵە.")
        return
    }
    kw := IniRead(IniFile, "Settings", "Keywords", DefaultKeywords)
    if !InStr("|" kw "|", "|" key "|")
        kw .= "|" key
    IniWrite(kw, IniFile, "Settings", "Keywords")
    MsgBox("ناوی تاب زیاد کرا: " key)
}

; ---------- پشکنین ----------
^!F2:: {
    title := WinGetTitle("A")
    proc := WinGetProcessName("A")
    task := SiteTask()
    MsgBox("وێبگەڕ: " proc "`nناوی پەنجەرە: " title "`n`nدەناسرێتەوە: " (task != "" ? "بەڵێ ✔" : "نەخێر ✘") "`nجۆری تاسک: " (task != "" ? task : "—"), "پشکنین")
}
