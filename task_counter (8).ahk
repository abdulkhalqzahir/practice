#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  task_counter.ahk  (وەشانی 16 — Supabase، ناردنی ڕاستەوخۆ و بێ دووبارەبوونەوە)
;  - Shift+Enter ی کیبۆرد دەژمێرێت (تەنها لەسەر ماڵپەڕی xawan)
;  - کلیکی لای ڕاست = Shift+Enter (و دەژمێردرێت). F12 = چالاک/ناچالاک
;  - F2           = ژمارەی ئێستا + ئەمڕۆ بەپێی جۆر + مێژوو
;  - Ctrl+Alt+F1  = ناوی تابی ئێستا زیاد دەکات وەک «جۆری تاسک»
;  - Ctrl+Alt+F2  = پشکنین
;  - fn+F3        = گۆڕینی ناو / جۆری تاسک
;  - Ctrl+Alt+F4  = پشکنینی پەیوەندی بە Supabase
;  - fn+F5 (٢ چرکە) یان Ctrl+Alt+F5 = سفرکردنەوەی ژمارەکان (لێرە + لە ماڵپەڕ)
;
;  ناردن: هەر Shift+Enter ێک ژمارەیەکی تایبەتی (seq) وەردەگرێت، یەکسەر لە ژورنالی فایلدا دەپارێزرێت و دەنێردرێت.
;  سێرڤەر هەر seq ێک تەنها یەکجار قبوڵ دەکات، بۆیە ئەگەر ئینتەرنێت پچڕا و داواکاری دووبارە نێردرایەوە
;  نە دووجار دەژمێردرێت و نە ون دەبێت. ئەگەر ئینتەرنێت نەبوو، لە ژورنال دەمێنێتەوە و دواتر خۆکار دەنێردرێت.
;  داگرتنی بەردەوامی Shift+Enter (auto-repeat) تەنها یەکجار دەژمێردرێت (بۆ گۆڕین: Settings → CountRepeat=1).
; ============================================================

global SB_URL := "https://zpjtavgezkfugstnymzu.supabase.co"
global SB_KEY := "sb_publishable_Ukx_q5n5wCd7n7K4qWkudg_IXnOoLvd"
global RpcBase := SB_URL "/rest/v1/rpc/"

global IniDir  := A_AppData "\ShiftEnterCounter"
DirCreate(IniDir)
global IniFile := IniDir "\shift_enter_count.ini"
global Browsers := "msedge.exe|chrome.exe|firefox.exe|brave.exe|opera.exe"
global ResetHours := 10
global DefaultKeywords := "xawan|خاوەن|خاوه‌ن|پلاتفۆرم|indexing"

; ---------- ناوی جۆری تاسک پاک دەکاتەوە ----------
CleanTask(s) {
    s := Trim(s)
    s := RegExReplace(s, '[=|"\\\[\]\r\n]', "")
    return Trim(SubStr(s, 1, 40))
}

JName(s) {
    s := StrReplace(StrReplace(s, '"', ""), Chr(92), "")
    return RegExReplace(s, "[\r\n\t]", " ")
}

NowEpoch() {
    return DateDiff(A_NowUTC, "19700101", "Seconds")
}

NewRid() {
    return NowEpoch() "-" Random(100000, 999999) "-" Random(100000, 999999)
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
    for k in StrSplit(KW, "|") {
        k := Trim(k)
        if (k != "" && InStr(title, k))
            return TaskName != "" ? TaskName : "گشتی"
    }
    return ""
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

; ============ Shift+Enter ============
; Press(): زۆر خێرایە — تەنها دەیخاتە ڕیزەوە و دەگەڕێتەوە، بۆ ئەوەی هیچ داگرتنێک ون نەبێت.
Press() {
    Critical
    global Seq
    task := SiteTask()
    if (task = "")
        return
    Seq += 1
    Q.Push({s: Seq, d: FormatTime(, "yyyy-MM-dd"), t: task})
    SetTimer(Drain, -1)
}

; ژورنال (فایل) + ناردنی یەکسەر. پێش هەموو شتێک دەنووسرێت بۆ ئەوەی ئەگەر کۆمپیوتەر کوژایەوە ون نەبێت.
Drain() {
    Critical
    global Q
    if (Q.Length = 0) {
        SendBatch()
        return
    }
    batch := Q
    Q := []
    txt := ""
    for e in batch {
        txt .= e.s "|" e.d "|" e.t "`n"
        Events.Push(e)
    }
    try FileAppend(txt, JrFile, "UTF-8-RAW")
    SendBatch()
    LocalStats(batch)                 ; ئامارە ناوخۆییەکان (F2)
}

LocalStats(batch) {
    Rollover()
    if (IniRead(IniFile, "Current", "Start", "") = "") {
        IniWrite(A_Now, IniFile, "Current", "Start")
        IniWrite(0, IniFile, "Current", "Count")
    }
    IniWrite(Integer(IniRead(IniFile, "Current", "Count", "0")) + batch.Length, IniFile, "Current", "Count")
    inc := Map()
    for e in batch {
        k := e.d "|" e.t
        inc[k] := (inc.Has(k) ? inc[k] : 0) + 1
    }
    for k, n in inc
        IniWrite(Integer(IniRead(IniFile, "Tasks", k, "0")) + n, IniFile, "Tasks", k)
}

; ---------- فایلی ini ----------
if (!FileExist(IniFile) && FileExist(A_ScriptDir "\shift_enter_count.ini"))
    FileCopy(A_ScriptDir "\shift_enter_count.ini", IniFile)

if !FileExist(IniFile)
    FileAppend("[Settings]`n", IniFile, "UTF-16")

FixIniEncoding() {
    try {
        buf := FileRead(IniFile, "RAW")
        if (buf.Size = 0 || (buf.Size >= 2 && NumGet(buf, 0, "UShort") = 0xFEFF))
            return
        txt := FileRead(IniFile, "CP0")
        try FileDelete(IniFile ".tmp")
        FileAppend(txt, IniFile ".tmp", "UTF-16")
        FileMove(IniFile ".tmp", IniFile, 1)
    }
}
FixIniEncoding()

; سکریپتە کۆنەکەی کلیکی ڕاست ئەگەر کراوەیە دایدەخات
DetectHiddenWindows true
for hwnd in WinGetList("ahk_class AutoHotkey") {
    if (hwnd != A_ScriptHwnd && InStr(WinGetTitle(hwnd), "RightClick_ShiftEnter"))
        try WinClose(hwnd)
}
DetectHiddenWindows false

global RightClickOn := IniRead(IniFile, "Settings", "RightClick", "1") = "1"
global PersonName := IniRead(IniFile, "Settings", "PersonName", "")
global TaskName := IniRead(IniFile, "Settings", "TaskName", "")
global Rid := IniRead(IniFile, "Settings", "Rid", "")
global KW := IniRead(IniFile, "Settings", "Keywords", DefaultKeywords)
global CountRepeat := IniRead(IniFile, "Settings", "CountRepeat", "0") = "1"

; ============ تۆڕ: WinHttp و WinINet + ناردنی ناسینکرۆن ============
global UseInet := IniRead(IniFile, "Settings", "UseInet", "0") = "1"
global Inflight := []
global Seq := 0, Q := [], Events := [], Sending := false, SendDelay := 500, EnterHeld := false
global JrFile := IniDir "\journal.txt"
global LastSendInfo := "هێشتا هیچ نەنێردراوە"

MakeReq(via, ms := 10000) {
    if (via = "winhttp") {
        r := ComObject("WinHttp.WinHttpRequest.5.1")
        r.SetTimeouts(ms, ms, ms, ms * 2)
        try r.Option[9] := 0x0A80        ; TLS 1.2
        return r
    }
    return ComObject("MSXML2.XMLHTTP.6.0")
}

SetTransport(toInet) {
    global UseInet
    if (UseInet = toInet)
        return
    UseInet := toInet
    IniWrite(toInet ? 1 : 0, IniFile, "Settings", "UseInet")
}

LogNet(msg) {
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg "`n", IniDir "\net_log.txt", "UTF-8")
}

; داواکاری ڕاستەوخۆ (چاوەڕێ دەکات) — تەنها بۆ پشکنین، سفرکردنەوە و داخستن
HttpSync(fn, body, ms := 10000) {
    order := UseInet ? ["inet", "winhttp"] : ["winhttp", "inet"]
    res := {status: 0, text: "", via: "", err: "", ms: 0}
    for via in order {
        t0 := A_TickCount
        try {
            r := MakeReq(via, ms)
            r.Open("POST", RpcBase fn, false)
            r.SetRequestHeader("apikey", SB_KEY)
            r.SetRequestHeader("Content-Type", "application/json")
            r.Send(body)
            res.status := r.Status
            res.text := r.ResponseText
            res.via := via
            res.ms := A_TickCount - t0
            res.err := ""
            return res
        } catch as e {
            res.err .= via " (" (A_TickCount - t0) "ms): " e.Message "`n"
        }
    }
    return res
}

; داواکاری ناسینکرۆن: هیچ کاتێک سکریپتەکە گیر ناکات. cb(ok, status, text)
Rpc(fn, body, cb := "", tries := 0, forceVia := "") {
    via := forceVia != "" ? forceVia : (UseInet ? "inet" : "winhttp")
    try {
        r := MakeReq(via)
        r.Open("POST", RpcBase fn, true)
        r.SetRequestHeader("apikey", SB_KEY)
        r.SetRequestHeader("Content-Type", "application/json")
        r.Send(body)
        Inflight.Push({req: r, via: via, fn: fn, body: body, cb: cb, tries: tries, t: A_TickCount})
    } catch as e {
        LogNet("Open/Send failed via " via ": " e.Message)
        RpcFailed({via: via, fn: fn, body: body, cb: cb, tries: tries})
    }
}

RpcFailed(it) {
    if (it.tries < 1) {                       ; ڕێگای دووەم تاقی بکەرەوە
        other := (it.via = "winhttp") ? "inet" : "winhttp"
        Rpc(it.fn, it.body, it.cb, it.tries + 1, other)
        return
    }
    LogNet("Failed on both transports: " it.fn)
    if IsObject(it.cb)
        it.cb.Call(false, 0, "")
}

PollInflight() {
    global LastSendInfo
    i := 1
    while (i <= Inflight.Length) {
        it := Inflight[i]
        done := false, netErr := false, status := 0, text := ""
        try {
            if (it.via = "winhttp")
                done := it.req.WaitForResponse(0.02)
            else
                done := (it.req.readyState = 4)
            if done {
                status := it.req.Status
                text := it.req.ResponseText
            }
        } catch {
            done := true
            netErr := true
        }
        if (!done && A_TickCount - it.t > 30000) {
            done := true
            netErr := true
        }
        if !done {
            i++
            continue
        }
        Inflight.RemoveAt(i)
        if (netErr || status = 0) {
            LastSendInfo := FormatTime(, "HH:mm:ss") "  ✘ نەگەیشت بە ئینتەرنێت/Supabase"
            RpcFailed(it)
            continue
        }
        okHttp := (status >= 200 && status < 300)
        LastSendInfo := FormatTime(, "HH:mm:ss") "  " (okHttp ? "✔ نێردرا" : "✘ Supabase HTTP " status " " SubStr(RegExReplace(text, "\s+", " "), 1, 120))
        if (it.via != (UseInet ? "inet" : "winhttp"))
            SetTransport(it.via = "inet")
        if IsObject(it.cb)
            it.cb.Call(okHttp, status, text)
    }
}

; ============ ناردنی ژورنال ============
; هەموو ئەو Shift+Enter انەی هێشتا سێرڤەر پشتڕاستی نەکردوونەتەوە، بە ڕیزبەندی دەنێردرێن.
SendBatch() {
    global Sending
    if (Sending || PersonName = "" || Rid = "" || Events.Length = 0)
        return
    Sending := true
    n := Min(Events.Length, 500)
    ev := ""
    last := 0
    Loop n {
        e := Events[A_Index]
        ev .= (A_Index > 1 ? "," : "") '{"s":' e.s ',"d":"' e.d '","t":"' JName(e.t) '"}'
        last := e.s
    }
    Rpc("record_batch", '{"p_rid":"' Rid '","p_events":[' ev ']}', BatchDone.Bind(last))
}

BatchDone(last, ok, status, text) {
    global Sending, SendDelay
    Sending := false
    if (ok && RegExMatch(text, '"ok"\s*:\s*true')) {
        TrimEvents(last)
        SendDelay := 500
        if (Events.Length > 0)
            SetTimer(SendBatch, -1)             ; ئەوانەی لە کاتی ناردنەکەدا زیاد بوون یەکسەر دەچن
        return
    }
    if (ok && InStr(text, "not registered")) {
        RegisterRemote(() => SetTimer(SendBatch, -300))
        return
    }
    if (status > 0)                             ; گەیشتە سێرڤەر بەڵام هەڵەی هەبوو
        ReportError(status " " text)
    SendDelay := Min(SendDelay * 2, 10000)       ; دووبارە هەوڵ دەداتەوە، هیچ ژمارەیەک ناسڕێتەوە
    SetTimer(SendBatch, -SendDelay)
}

; ئەوانەی سێرڤەر وەریگرتن (s <= last) لە ژورنال لادەبرێن
TrimEvents(last) {
    Critical
    global Events
    while (Events.Length > 0 && Events[1].s <= last)
        Events.RemoveAt(1)
    txt := ""
    for e in Events
        txt .= e.s "|" e.d "|" e.t "`n"
    try FileDelete(JrFile)
    if (txt != "")
        try FileAppend(txt, JrFile, "UTF-8-RAW")
    IniWrite(last, IniFile, "Settings", "AckSeq")
}

; کاتی کردنەوە: ژورنالی نەنێردراو دەخوێنێتەوە (و ژمارە چاوەڕێکراوەکانی وەشانی کۆن دەگۆڕێت)
LoadJournal() {
    global Seq, Events
    Events := []
    mx := Integer(IniRead(IniFile, "Settings", "AckSeq", "0"))
    try
        txt := FileRead(JrFile, "UTF-8")
    catch
        txt := ""
    for line in StrSplit(txt, "`n", "`r") {
        p := StrSplit(line, "|")
        if (p.Length < 3 || !IsInteger(p[1]))
            continue
        Events.Push({s: Integer(p[1]), d: p[2], t: p[3]})
        mx := Max(mx, Integer(p[1]))
    }
    Seq := mx
    try section := IniRead(IniFile, "Pending")
    catch
        section := ""
    add := ""
    for line in StrSplit(section, "`n", "`r") {
        i := InStr(line, "=")
        if (i < 12)
            continue
        key := SubStr(line, 1, i - 1)
        n := SubStr(line, i + 1)
        if (SubStr(key, 11, 1) != "|" || !IsInteger(n) || Integer(n) <= 0)
            continue
        Loop Integer(n) {
            Seq += 1
            e := {s: Seq, d: SubStr(key, 1, 10), t: SubStr(key, 12)}
            Events.Push(e)
            add .= e.s "|" e.d "|" e.t "`n"
        }
    }
    if (add != "") {
        try FileAppend(add, JrFile, "UTF-8-RAW")
        IniDelete(IniFile, "Pending")
    }
}

ReportError(msg) {
    if (Rid = "")
        return
    msg := JName(SubStr(RegExReplace(msg, "\s+", " "), 1, 300))
    Rpc("report_worker_error", '{"p_rid":"' Rid '","p_error":"' msg '"}')
}

RegisterRemote(after := "") {
    if (PersonName = "" || Rid = "")
        return
    body := '{"p_rid":"' Rid '","p_person_name":"' JName(PersonName) '","p_task_name":"' JName(TaskName) '"}'
    Rpc("register_worker", body, RegDone.Bind(after))
}

RegDone(after, ok, status, text) {
    if ok {
        if IsObject(after)
            after.Call()
        return
    }
    SetTimer(() => RegisterRemote(after), -15000)
}

Heartbeat() {
    global Sending
    if (PersonName = "" || Rid = "")
        return
    if (Sending && Inflight.Length = 0)       ; پاراستن: ئەگەر Sending گیرابوو
        Sending := false
    SendBatch()
    Rpc("heartbeat_worker", '{"p_rid":"' Rid '"}', HeartDone)
}

HeartDone(ok, status, text) {
    if (ok && InStr(text, "not registered"))
        RegisterRemote(() => SendBatch())
    else if ok
        SendBatch()
}

SendOffline(oldRid) {
    if (oldRid = "")
        return
    try HttpSync("deactivate_worker", '{"p_rid":"' oldRid '"}', 5000)
}

; ============ تۆمارکردن ============
Register() {
    global PersonName, TaskName, Rid
    r := InputBox("ناوی خۆت بنووسە", "تۆمارکردن", , PersonName)
    if (r.Result != "OK" || Trim(r.Value) = "")
        return
    tk := InputBox("ناوی تاسک (جۆری کارەکەت) بنووسە", "تۆمارکردن", , TaskName)
    if (tk.Result != "OK" || CleanTask(tk.Value) = "")
        return
    newName := Trim(r.Value)
    if (Rid != "" && PersonName != "" && PersonName != newName) {
        SendOffline(Rid)                         ; ناوی کۆن ناچالاک دەبێت
        Rid := ""
    }
    PersonName := newName
    TaskName := CleanTask(tk.Value)
    IniWrite(PersonName, IniFile, "Settings", "PersonName")
    IniWrite(TaskName, IniFile, "Settings", "TaskName")
    if (Rid = "") {
        Rid := NewRid()
        IniWrite(Rid, IniFile, "Settings", "Rid")
    }
    RegisterRemote(() => SendBatch())
    MsgBox("تۆمار کرا ✔`nناو: " PersonName "`nتاسک: " TaskName, "تۆمارکردن")
}

ClearLocal() {
    Critical
    global Events, Q
    Events := []
    Q := []
    try FileDelete(JrFile)
    IniDelete(IniFile, "Tasks")
    IniDelete(IniFile, "History")
    IniDelete(IniFile, "Current")
    IniDelete(IniFile, "Pending")
}

PendingTotal() {
    return Events.Length + Q.Length
}

BuildDays() {
    days := Map()
    try section := IniRead(IniFile, "Tasks")
    catch
        section := ""
    for line in StrSplit(section, "`n", "`r") {
        i := InStr(line, "=")
        if (i < 12)
            continue
        key := SubStr(line, 1, i - 1)
        v := SubStr(line, i + 1)
        if (SubStr(key, 11, 1) != "|" || !IsInteger(v))
            continue
        d := SubStr(key, 1, 10)
        if !days.Has(d)
            days[d] := Map()
        days[d][SubStr(key, 12)] := Integer(v)
    }
    return days
}

; کاتێک سکریپتەکە دادەخرێت، ماڵپەڕ دەزانێت کە ناچالاکە (ژمارە نەنێردراوەکان لە فایلدا دەمێننەوە)
ExitHandler(reason, code) {
    if (reason = "Reload" || reason = "Single")
        return
    if (PersonName != "" && Rid != "")
        SendOffline(Rid)
}
OnExit(ExitHandler)

if (PersonName != "" && Rid = "") {
    Rid := NewRid()
    IniWrite(Rid, IniFile, "Settings", "Rid")
}

LoadJournal()

ToolTip("task_counter وەشانی 16 (Supabase) ✔`nناو: " (PersonName != "" ? PersonName : "—") "  |  تاسک: " (TaskName != "" ? TaskName : "—") "  (fn+F3 بۆ گۆڕین)`nکلیکی لای ڕاست = Shift+Enter: " (RightClickOn ? "چالاک ✔" : "ناچالاک ✘  (F12 بۆ چالاککردن)"))
SetTimer(() => ToolTip(), -4000)
SetTimer(PollInflight, 60)
OnMessage(0x5555, (*) => SendBatch())
OnMessage(0x5556, (*) => Press())
SetTimer(Heartbeat, 30000)                          ; هەر 30 چرکە: «چالاکم» + ناردنی ماوە

if (PersonName = "" || TaskName = "")
    Register()
else {
    SetTimer(() => RegisterRemote(() => SendBatch()), -1500)   ; دوای کردنەوە: چالاک + ناردنی ژمارە ماوەکان
}

; ============ Hotkeys ============
$F3:: Register()

; ---------- پشکنینی پەیوەندی ----------
^!F4:: {
    if (PersonName = "" || Rid = "") {
        MsgBox("هێشتا تۆمار نەکراویت. fn+F3 دابگرە.", "پشکنین")
        return
    }
    ToolTip("دەپشکنرێت... (ڕەنگە تا 30 چرکە بخایەنێت)")
    r := HttpSync("register_worker", '{"p_rid":"' Rid '","p_person_name":"' JName(PersonName) '","p_task_name":"' JName(TaskName) '"}', 12000)
    ToolTip()
    if (r.via != "") {
        SetTransport(r.via = "inet")
        good := (r.status >= 200 && r.status < 300)
        extra := ""
        if InStr(r.text, "PGRST202") || InStr(r.text, "PGRST205")
            extra := "`n`nخشتە/فەنکشنەکان لە Supabase نین: supabase_full.sql لە SQL Editor ی هەمان پڕۆژە بە تەواوی Run بکە."
        MsgBox((good ? "سەرکەوتوو بوو ✔" : "گەیشت بە Supabase بەڵام هەڵە هەیە ✘") "`nڕێگا: " (r.via = "inet" ? "WinINet" : "WinHttp") " (" r.ms " ms)`nHTTP: " r.status "`n`n" SubStr(r.text, 1, 400) extra "`n`nچاوەڕێی ناردن: " PendingTotal(), "پشکنینی پەیوەندی")
        if good
            SendBatch()
        return
    }
    g := HttpSync("x", "{}", 6000)
    net := (g.via != "") ? "ئینتەرنێت کاردەکات، بەڵام Supabase ناگات." : "ئینتەرنێتیش ناگات."
    MsgBox("نەگەیشت بە Supabase ✘`n`n" r.err "`n" net "`n`nچارەسەر: VPN یان DNS ی گشتی (1.1.1.1 / 8.8.8.8) تاقی بکەرەوە، Firewall/Antivirus بپشکنە.`nنیگەران مەبە: ژمارەکان ناچن و دواتر خۆکار دەنێردرێن.", "پشکنینی پەیوەندی")
}

; ---------- سفرکردنەوە ----------
ResetAll() {
    if (PersonName = "" || Rid = "") {
        MsgBox("هێشتا تۆمار نەکراویت. fn+F3 دابگرە.", "سفرکردنەوە")
        return
    }
    if (MsgBox("هەموو ژمارەکانی ئەم کۆمپیوتەر و ماڵپەڕ سفر بکرێنەوە؟", "سفرکردنەوە", "YesNo Icon!") != "Yes")
        return
    r := HttpSync("reset_worker_counts", '{"p_rid":"' Rid '"}', 12000)
    if (r.via = "" || r.status >= 400) {
        MsgBox("نەتوانرا ماڵپەڕ سفر بکرێتەوە (ئینتەرنێت؟). هیچ ژمارەیەک نەگۆڕدرا. دووبارە هەوڵ بدەرەوە.", "سفرکردنەوە", "Icon!")
        return
    }
    ClearLocal()
    MsgBox("ژمارەکان لەم کۆمپیوتەر و لە ماڵپەڕ سفر کرانەوە ✔", "سفرکردنەوە")
}

~F5:: {
    ToolTip("بەردەوام بە لە دابگرتنی F5 بۆ سفرکردنەوە...")
    held := !KeyWait("F5", "T2")
    ToolTip()
    if held
        ResetAll()
}
^!F5:: ResetAll()

; ---------- کلیکی لای ڕاست => Shift+Enter (و دەژمێردرێت) ----------
#MaxThreadsBuffer true
#HotIf RightClickOn && !WinActive("ahk_pid " DllCall("GetCurrentProcessId"))
RButton:: {
    Send "+{Enter}"
    Press()
}
#HotIf
#MaxThreadsBuffer false

F12:: {
    global RightClickOn
    RightClickOn := !RightClickOn
    IniWrite(RightClickOn ? 1 : 0, IniFile, "Settings", "RightClick")
    ToolTip("کلیکی لای ڕاست = Shift+Enter: " (RightClickOn ? "چالاک ✔" : "ناچالاک"))
    SetTimer(() => ToolTip(), -1500)
}

; ---------- Shift+Enter ی کیبۆرد ----------
#MaxThreadsBuffer true
~+Enter:: {
    global EnterHeld
    if (EnterHeld && !CountRepeat && GetKeyState("Enter", "P"))
        return                       ; داگرتنی بەردەوام (auto-repeat) = هەمان داگرتن
    EnterHeld := true
    Press()
}
~Enter up:: {
    global EnterHeld
    EnterHeld := false
}
#MaxThreadsBuffer false

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
        if (p.Length < 2 || !IsInteger(p[2]))
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
        . "ماوەکانی پێشوو:`n" lines "`n"
        . "چاوەڕێی ناردن: " PendingTotal() "`n"
        . "دوایین ناردن بۆ ماڵپەڕ: " LastSendInfo, "ژمارەی Shift+Enter")
}

; ---------- زیادکردنی ناوی تاب (جۆری تاسک) ----------
^!F1:: {
    title := WinGetTitle("A")
    key := CleanTask(RegExReplace(title, "\s[-–—]\s.*$", ""))
    if (key = "") {
        MsgBox("ناوی تاب بەتاڵە.")
        return
    }
    global KW
    kw := IniRead(IniFile, "Settings", "Keywords", DefaultKeywords)
    if !InStr("|" kw "|", "|" key "|")
        kw .= "|" key
    IniWrite(kw, IniFile, "Settings", "Keywords")
    KW := kw
    MsgBox("ناوی تاب زیاد کرا: " key)
}

; ---------- پشکنین ----------
^!F2:: {
    title := WinGetTitle("A")
    proc := WinGetProcessName("A")
    task := SiteTask()
    MsgBox("وێبگەڕ: " proc "`nناوی پەنجەرە: " title "`n`nدەناسرێتەوە: " (task != "" ? "بەڵێ ✔" : "نەخێر ✘") "`nجۆری تاسک: " (task != "" ? task : "—"), "پشکنین")
}
