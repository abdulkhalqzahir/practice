#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
;  shift_enter_counter.ahk
;  - Shift+Enter ی کیبۆرد دەژمێرێت (تەنها لەسەر ماڵپەڕی xawan)
;  - هەر Shift+Enter ێک لەگەڵ «جۆری تاسک» تۆمار دەکرێت (ناوی تابەکە)
;  - کلیکی لای ڕاست = Shift+Enter (و دەژمێردرێت، بە هەمان جۆری تاسکەوە). F11 = چالاک/ناچالاک
;    (پێویست ناکات RightClick_ShiftEnter.ahk بەتەنیا بکرێتەوە، ئەمە جێگەی گرتووەتەوە)
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
    RequestFast()                   ; ڕاستەوخۆ دەنێردرێت بۆ ماڵپەڕ
}

; گواستنەوەی ژمارە کۆنەکان (ئەگەر فایلی کۆن لە تەنیشت سکریپتەکەیە)
if (!FileExist(IniFile) && FileExist(A_ScriptDir "\shift_enter_count.ini"))
    FileCopy(A_ScriptDir "\shift_enter_count.ini", IniFile)

; فایلی ini بە UTF-16 دروست دەبێت بۆ ئەوەی ناوی کوردی دروست بمێنێتەوە
if !FileExist(IniFile)
    FileAppend("[Settings]`n", IniFile, "UTF-16")

; ئەگەر فایلی ini ANSI بێت (وەشانە کۆنەکان)، دەیگۆڕێت بۆ UTF-16 تا ناوی کوردی نەشێوێت
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

; سکریپتە کۆنەکەی کلیکی ڕاست (RightClick_ShiftEnter) ئەگەر کراوەیە دایدەخات،
; چونکە ئەو ژمارەکان بە فۆرماتی کۆن دەژمێرێت و نایگاتە ماڵپەڕ
DetectHiddenWindows true
for hwnd in WinGetList("ahk_class AutoHotkey") {
    if (hwnd != A_ScriptHwnd && InStr(WinGetTitle(hwnd), "RightClick_ShiftEnter"))
        try WinClose(hwnd)
}
DetectHiddenWindows false

global RightClickOn := IniRead(IniFile, "Settings", "RightClick", "1") = "1"

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

; ============ تۆڕ: دوو ڕێگا (WinHttp و WinINet) + ناردنی ناسینکرۆن ============
; WinHttp هەندێک جار بە پڕۆکسی/VPN/فایەروۆڵ ناگات، بەڵام WinINet (وەک وێبگەڕ) دەگات.
; ئەگەر یەکەم ڕێگا شکستی هێنا، خۆکار ڕێگای دووەم تاقی دەکاتەوە و ئەوەی کاری کرد دەیپارێزێت.
global UseInet := IniRead(IniFile, "Settings", "UseInet", "0") = "1"
global Inflight := []
global NetOK := true
global LastCheck := 0
global LastFast := 0
global BlockUntil := 0      ; ئەگەر Pantry 429 ی دا، تا ئەم کاتە هیچ نانێرین
global Backoff := 0
global FastGap := 2000      ; کەمترین ماوە لە نێوان دوو ناردندا (ms). Pantry تەنها 2 داواکاری/چرکە قبوڵ دەکات بۆ هەمووان
global PantryBase := "https://getpantry.cloud/apiv1/pantry/"

Tip(text, ms := 1500) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

MakeReq(via, ms := 10000) {
    if (via = "winhttp") {
        r := ComObject("WinHttp.WinHttpRequest.5.1")
        r.SetTimeouts(ms, ms, ms, ms * 2)
        try r.Option[9] := 0x0A80        ; TLS 1.0/1.1/1.2 چالاک دەکات (Windows 7/8 بە بنەڕەت TLS 1.2 ناکات)
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

; داواکاری ڕاستەوخۆ (چاوەڕێ دەکات). تەنها بۆ پشکنین و داخستن بەکاردێت.
HttpSync(method, url, body := "", ms := 10000, single := false) {
    order := UseInet ? ["inet", "winhttp"] : ["winhttp", "inet"]
    res := {status: 0, text: "", via: "", err: "", ms: 0}
    for via in order {
        t0 := A_TickCount
        try {
            r := MakeReq(via, ms)
            r.Open(method, url, false)
            if (body != "")
                r.SetRequestHeader("Content-Type", "application/json")
            else
                r.SetRequestHeader("Cache-Control", "no-cache")
            if (body != "")
                r.Send(body)
            else
                r.Send()
            res.status := r.Status
            res.text := r.ResponseText
            res.via := via
            res.ms := A_TickCount - t0
            res.err := ""
            return res
        } catch as e {
            res.err .= via " (" (A_TickCount - t0) "ms): " e.Message "`n"
        }
        if single
            break
    }
    return res
}

; داواکاری ناسینکرۆن: هیچ کاتێک سکریپتەکە گیر ناکات
HttpAsync(method, url, body := "", kind := "put", after := "", tries := 0, forceVia := "") {
    via := forceVia != "" ? forceVia : (UseInet ? "inet" : "winhttp")
    try {
        r := MakeReq(via)
        r.Open(method, url, true)
        r.SetRequestHeader("Content-Type", "application/json")
        if (method = "GET")
            r.SetRequestHeader("Cache-Control", "no-cache")
        if (body != "")
            r.Send(body)
        else
            r.Send()
        Inflight.Push({req: r, via: via, method: method, url: url, body: body, kind: kind, after: after, tries: tries, t: A_TickCount})
    } catch as e {
        LogNet("Open/Send failed via " via ": " e.Message)
        FailedItem({via: via, method: method, url: url, body: body, kind: kind, after: after, tries: tries})
    }
}

; ئەگەر ڕێگایەک شکستی هێنا: ڕێگای دووەم تاقی بکەرەوە
FailedItem(it) {
    global NetOK
    if (it.tries < 1) {
        other := (it.via = "winhttp") ? "inet" : "winhttp"
        HttpAsync(it.method, it.url, it.body, it.kind, it.after, it.tries + 1, other)
        return
    }
    if (NetOK) {
        NetOK := false
        LogNet("Send failed on both transports: " it.url)
        ToolTip("ناردن بۆ ماڵپەڕ سەرکەوتوو نەبوو — Ctrl+Alt+F4 بۆ پشکنین")
        SetTimer(() => ToolTip(), -2500)
    }
    if IsObject(it.after)
        it.after.Call()
}

PollInflight() {
    global NetOK, Backoff, BlockUntil
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
            FailedItem(it)
            continue
        }
        ; گەیشت بە سێرڤەر
        if (it.via != (UseInet ? "inet" : "winhttp"))
            SetTransport(it.via = "inet")        ; ئەو ڕێگایەی کاری کرد دەیپارێزین
        if (!NetOK) {
            NetOK := true
            LogNet("Network OK again via " it.via)
        }
        if (it.kind = "reset")
            HandleReset(status, text)
        else if (status = 429 || status >= 500) {
            ; Pantry زۆر داواکاری بینیوە: بێدەنگ دەوەستین و دواتر (بە ماوەیەکی هەڕەمەکی) دووبارە دەنێرین
            Backoff := Backoff ? Min(Backoff * 2, 20000) : 2000
            wait := Backoff + Random(0, 1500)
            BlockUntil := A_TickCount + wait
            SetTimer(FastSend, -wait)
            LogNet("HTTP " status " - waiting " wait " ms")
        } else {
            Backoff := 0
        }
        if IsObject(it.after)
            it.after.Call()
    }
}


; ئەگەر بەڕێوەبەر لە داشبۆرد «سفرکردنەوەی داتا» ی کرد، ژمارەکانی ئێرەش خۆکار سفر دەکرێنەوە
CheckResetThen(after) {
    HttpAsync("GET", PantryBase PantryId "/basket/reset", "", "reset", after)
}

HandleReset(status, text) {
    last := IniRead(IniFile, "Settings", "ResetId", "")
    ; ئەگەر بەڕێوەبەر ئەم کەسەی سڕیبێتەوە
    if (status = 200 && PersonName != "" && RegExMatch(text, '\Q"' JName(PersonName) '"\E\s*:\s*(\d+)', &rm)) {
        if (Integer(rm[1]) > Integer(IniRead(IniFile, "Settings", "RegisteredAt", "0")) * 1000) {
            RemoveSelf()
            return
        }
    }
    if (status = 200 && RegExMatch(text, '"id"\s*:\s*(\d+)', &m)) {
        rid := Integer(m[1])
        if (last = "")
            IniWrite(rid, IniFile, "Settings", "ResetId")        ; یەکەمجار: تەنها دەیزانین
        else if (rid > Integer(last)) {
            ClearLocal()
            IniWrite(rid, IniFile, "Settings", "ResetId")
        }
    } else if (last = "" && status = 400) {
        IniWrite(0, IniFile, "Settings", "ResetId")
    }
}

; ژمارەی ئەمڕۆ + نیشانەی «چالاکم» (بچووک و خێرا)
BodyToday() {
    days := BuildDays()
    td := FormatTime(, "yyyy-MM-dd")
    js := ""
    if days.Has(td) {
        tj := ""
        for t, n in days[td]
            tj .= (tj = "" ? "" : ",") '"' t '":' n
        js := '"' td '":{' tj '}'
    }
    return '{"people":{"' JName(PersonName) '":{"seen":' NowEpoch() ',"active":1,"days":{' js '}}}}'
}

PutBasket(body, kind := "put") {
    global LastFast
    if (A_TickCount < BlockUntil) {              ; لە ماوەی چاوەڕوانیدایە؛ FastSend دواتر نوێترین داتا دەنێرێت
        SetTimer(FastSend, -(BlockUntil - A_TickCount + 300))
        return
    }
    LastFast := A_TickCount
    HttpAsync("PUT", PantryBase PantryId "/basket/shift", body, kind)
}

; هەر Shift+Enter ێک: یەکسەر دەنێردرێت. ئەگەر لە 1.5 چرکەی پێشوودا نێردرابێت،
; لە کۆتایی ئەو ماوەیەدا دەنێردرێت (بۆ ئەوەی Pantry داواکارییەکان بلۆک نەکات)
RequestFast() {
    gap := A_TickCount - LastFast
    if (gap >= FastGap)
        FastSend()
    else
        SetTimer(FastSend, -(FastGap - gap + Random(0, 400)))
}

FastSend() {
    if (PersonName = "" || PantryId = "")
        return
    PutBasket(BodyToday(), "fast")
}

; full = هەموو داتا؛ نەخێر = تەنها نیشانەی «چالاکم» (سووک و خێرا)
Sync(full := true) {
    global LastCheck
    if (PersonName = "" || PantryId = "")
        return
    if (!full && A_TickCount - LastFast < 35000)   ; تازە شتێک نێردراوە، نیشانەی چالاکی پێویست نییە
        return
    if (full || A_TickCount - LastCheck > 180000) {
        LastCheck := A_TickCount
        CheckResetThen((*) => SendSnapshot(full))     ; دوای پشکنینی سفرکردنەوە دەنێردرێت
    } else
        SendSnapshot(full)
}

SendSnapshot(full) {
    if (PersonName = "" || PantryId = "")        ; لەوانەیە لەم نێوەندەدا لابرابێت
        return
    PutBasket(full ? BuildBody() : BodyToday())
}

FullSync() {
    Sync(true)
}

; ناردنی ڕاستەوخۆ (بێ چاوەڕوانی زۆر) بۆ کاتی داخستن
SendNow(body, pid) {
    try HttpSync("PUT", PantryBase pid "/basket/shift", body, 2500, true)
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

ToolTip("task_counter وەشانی 10 ✔`nکلیکی لای ڕاست = Shift+Enter: " (RightClickOn ? "چالاک ✔" : "ناچالاک ✘  (F11 بۆ چالاککردن)"))
SetTimer(() => ToolTip(), -4000)
SetTimer(PollInflight, 150)                     ; ئەنجامی داواکارییە ناسینکرۆنەکان دەپشکنێت
OnMessage(0x5555, (*) => RequestFast())
OnMessage(0x5556, (*) => CountOne())          ; RightClick_ShiftEnter.ahk ئەمە دەنێرێت دوای هەر کلیکی لای ڕاست          ; entak.ahk ئەمە دەنێرێت دوای هەر دەبڵ-کلیکێک
SetTimer(Sync, 300000)                          ; هەر 5 خولەک: هەموو داتا
SetTimer(() => Sync(false), 45000)              ; هەر 45 چرکە: نیشانەی «چالاکم»
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
    ToolTip("دەپشکنرێت... (ڕەنگە تا 30 چرکە بخایەنێت)")
    body := BuildBody()
    r := HttpSync("PUT", PantryBase PantryId "/basket/shift", body, 12000)
    ToolTip()
    if (r.via != "") {
        SetTransport(r.via = "inet")
        MsgBox("سەرکەوتوو بوو ✔`nڕێگا: " (r.via = "inet" ? "WinINet" : "WinHttp") " (" r.ms " ms)`nئەنجام: " r.status "`n`n" SubStr(r.text, 1, 300) "`n`nنێردرا:`n" SubStr(body, 1, 600), "پشکنینی ناردن")
        return
    }
    ; هەردوو ڕێگا شکستیان هێنا: ئینتەرنێت بە گشتی هەیە؟
    g := HttpSync("GET", "https://www.microsoft.com", "", 6000, true)
    net := (g.via != "") ? "ئینتەرنێت کاردەکات، بەڵام getpantry.cloud ناگات." : "ئینتەرنێتیش ناگات."
    MsgBox("نەگەیشت بە getpantry.cloud ✘`n`n" r.err "`n" net "`n`n"
        . "چارەسەر:`n"
        . "1) VPN یان DNS ی گشتی (1.1.1.1 یان 8.8.8.8) تاقی بکەرەوە`n"
        . "2) ئەگەر پڕۆکسی بەکاردێنیت، لە Windows Settings ڕێکی بخە`n"
        . "3) Firewall/Antivirus ڕێگە بە AutoHotkey بدە`n"
        . "4) لە وێبگەڕ https://getpantry.cloud بکەرەوە، ئەگەر نەکرایەوە ISP بلۆکی کردووە", "پشکنینی ناردن")
}


; ---------- سفرکردنەوەی ژمارەکانی ئەم کۆمپیوتەرە ----------
^!F5:: {
    if (MsgBox("هەموو ژمارەکانی ئەم کۆمپیوتەرە سفر بکرێنەوە؟", "سفرکردنەوە", "YesNo Icon!") != "Yes")
        return
    ClearLocal()
    MsgBox("ژمارەکانی ئەم کۆمپیوتەرە سفر کرانەوە ✔", "سفرکردنەوە")
}

; ---------- کلیکی لای ڕاست => Shift+Enter (و دەژمێردرێت) ----------
#HotIf RightClickOn && !WinActive("ahk_pid " DllCall("GetCurrentProcessId"))
RButton:: {
    Send "+{Enter}"
    CountOne()
}
#HotIf

; F11 = کلیکی لای ڕاست وەک Shift+Enter چالاک / ناچالاک بکە
F11:: {
    global RightClickOn
    RightClickOn := !RightClickOn
    IniWrite(RightClickOn ? 1 : 0, IniFile, "Settings", "RightClick")
    ToolTip("کلیکی لای ڕاست = Shift+Enter: " (RightClickOn ? "چالاک ✔" : "ناچالاک"))
    SetTimer(() => ToolTip(), -1500)
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
