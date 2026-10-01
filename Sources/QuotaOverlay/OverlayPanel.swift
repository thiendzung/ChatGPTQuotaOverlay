import AppKit

private final class RingQuotaView: NSView {
    var onHover: (() -> Void)?
    var onHoverExit: (() -> Void)?
    var contextMenuProvider: (() -> NSMenu?)?

    var quota: Quota = .unavailable {
        didSet { needsDisplay = true }
    }

    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    override func mouseExited(with event: NSEvent) {
        onHoverExit?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let trackColor = NSColor.separatorColor.withAlphaComponent(0.34)

        drawRing(
            percent: quota.fiveHourPercent,
            center: center,
            radius: 19.0,
            lineWidth: 3.4,
            trackColor: trackColor,
            progressColor: .systemBlue
        )

        drawRing(
            percent: quota.weekPercent,
            center: center,
            radius: 14.0,
            lineWidth: 3.0,
            trackColor: trackColor,
            progressColor: .systemPurple
        )

        drawCenterValue(
            quota.fiveHourPercent.map(String.init) ?? "вЂ”",
            color: .systemBlue,
            y: center.y + 0.2
        )
        drawCenterValue(
            quota.weekPercent.map(String.init) ?? "вЂ”",
            color: .systemPurple,
            y: center.y - 8.2
        )
    }

    private func drawRing(
        percent: Int?,
        center: NSPoint,
        radius: CGFloat,
        lineWidth: CGFloat,
        trackColor: NSColor,
        progressColor: NSColor
    ) {
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: -270,
            clockwise: true
        )
        track.lineWidth = lineWidth
        track.lineCapStyle = .round
        trackColor.setStroke()
        track.stroke()

        guard let percent else { return }
        let clamped = max(0, min(100, percent))
        guard clamped > 0 else { return }

        let endAngle = 90.0 - (360.0 * CGFloat(clamped) / 100.0)
        let progress = NSBezierPath()
        progress.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: endAngle,
            clockwise: true
        )
        progress.lineWidth = lineWidth
        progress.lineCapStyle = .round
        progressColor.setStroke()
        progress.stroke()
    }

    private func drawCenterValue(_ text: String, color: NSColor, y: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.8, weight: .semibold),
            .foregroundColor: color,B€њ\YЬ\Э[N€\YЬ\€B‚€]™XЭH”Ф™XЭ
€›Э[™Л›ZYHLKN€KЪY€Њ‹ZYЪ€JB€
^\И”ФЭљ[™КK™]К[€™XЭЪ]]љXќ]\О€]љXќ]\КB€BџB‚њљ]]Hљ[[Ы\ЬИ][ЭUЫЫ\[™[€”Ф[™[В€љ]]H]X™[H”Х^љY[
X™[Ъ]Эљ[™О€ЌZ8 %0­ИЩYZИ8 %ЉB‚€[љ]

HВ€Э\\‹љ[љ]
€ЫЫќ[ќ™XЭ€”Ф™XЭ
€N€ЪY€M‹ZYЪ€Ћ
K€Э[SX\ЪО€Л›Ь™\›\ЬЛ››ЫXЭ]][™Ф[™[K€XЪЪ[™О€ќY™™\™Y€Y™\Ћ€[ЩB€
B‚€\УЬ\]YHH[ЩB€XЪЩЬ›Э[™ЫЫЬ€HЫX\‚€\ФЪYЭИHќYB€]™[H™›Ш][™В€ЫЫXЭ[Ыђ™Z]љ[Ь€HЛШ[’›Ъ[ђ[ЬXЩ\Л™ќ[ШЬ™Y[ђ]^[X\ћKљYЫ›Ь™\РЮXЫWB€Y\УЫ‘XXЭ]]HH[ЩB€YЫ›Ь™\У[Э\ЩQ]™[ќИHќYB‚€]ЫЫќZ[™\€H”ХљY]Књ[YN€ЫЫќ[ќ™XЭ
›Ь‘њ[YT™XЭ€њ[YJJB€ЫЫќZ[™\‹ќШ[ќУ^Y\€HќYB€ЫЫќZ[™\‹›^Y\ЏЛЫЬ›™\”Y]\ИHВ€ЫЫќZ[™\‹›^Y\ЏЛXЪЩЬ›Э[™ЫЫЬ€H”РЫЫЬ‹ќЪ[™ЭРXЪЩЬ›Э[™ЫЫЬ‹ќЪ][PЫЫ\Ы™[ќ
ЋMЉKЩРЫЫЬ‚€ЫЫќZ[™\‹›^Y\ЏЛ›Ь™\•ЪYHЌB€ЫЫќZ[™\‹›^Y\ЏЛ›Ь™\ђЫЫЬ€H”РЫЫЬ‹њЩ\\]ЬђЫЫЬ‹ќЪ][PЫЫ\Ы™[ќ
ЌJKЩРЫЫЬ‚‚€X™[ќ[њЫ]\Р]]Ь™\Ъ^љ[™УX\ЪТ[ќРЫЫњЭZ[ќИH[ЩB€X™[™›ЫќH”С›Ыќ›[Ы›ЬЬXЩYYЪ]Ю\Э[Q›Ыќ
Щ”Ъ^™N€LKЌKЩZYЪ€›YY][JB€X™[ќ^ЫЫЬ€H›X™[ЫЫЬ‚€X™[[YЫ›Y[ќHЩ[ќ\‚€X™[›[™Pњ™XZУ[ЩHHћPЫ\[™В‚€ЫЫќZ[™\‹YЭXќљY]КX™[
B€ЫЫќ[ќљY]ИHЫЫќZ[™\‚‚€”У^[Э]ЫЫњЭZ[ќXЭ]]JВ€X™[›XY[™Р[ЪЬ‹ЫЫњЭZ[ќ
\]X[О€ЫЫќZ[™\‹›XY[™Р[ЪЬ‹ЫЫњЭ[ќ€JK€X™[ќZ[[™Р[ЪЬ‹ЫЫњЭZ[ќ
\]X[О€ЫЫќZ[™\‹ќZ[[™Р[ЪЬ‹ЫЫњЭ[ќ€NJK€X™[Щ[ќ\–P[ЪЬ‹ЫЫњЭZ[ќ
\]X[О€ЫЫќZ[™\‹Щ[ќ\–P[ЪЬЉB€JB€B‚€ќ[И\]J^€Эљ[™КHВ€X™[њЭљ[™Х[YHH^€]ЪYHX^
M‹X™[љ[ќљ[њЪXРЫЫќ[ќЪ^™KќЪY
ИЊ
B€Щ]ЫЫќ[ќЪ^™J”ФЪ^™JЪY€ЪYZYЪ€Ћ
JB€BџB‚њљ]]Hљ[[Ы\ЬИY[ќPXЭ[Ы•\™Щ]€”УШљ™XЭВ€\€Ы”™Yњ™\Ъ€


HO€›ЪY
OВ€\€Ы”™\]Y\ЭXШЩ\ЬЪXљ[]N€


HO€›ЪY
OВ€\€Ы”]Z]€


HO€›ЪY
OВ‚€ШљИќ[И™Yњ™\Ъ
ИЩ[™\Ћ€[ћOКHИЫ”™Yњ™\ЪК
HB€ШљИќ[И™\]Y\ЭXШЩ\ЬЪXљ[]JИЩ[™\Ћ€[ћOКHИЫ”™\]Y\ЭXШЩ\ЬЪXљ[]OК
HB€ШљИќ[И]Z]
ИЩ[™\Ћ€[ћOКHИЫ”]Z]К
HBџB‚™љ[[Ы\ЬИЭ™\›^T[™[€”Ф[™[В€\€Ы’Э™\Ћ€


HO€›ЪY
OВ€\€Ы”™Yњ™\Ъ€


HO€›ЪY
OИВ€YЩ]ИY[ќU\™Щ]›Ы”™Yњ™\ЪHЫ”™Yњ™\ЪB€B€\€Ы”™\]Y\ЭXШЩ\ЬЪXљ[]N€


HO€›ЪY
OИВ€YЩ]ИY[ќU\™Щ]›Ы”™\]Y\ЭXШЩ\ЬЪXљ[]HHЫ”™\]Y\ЭXШЩ\ЬЪXљ[]HB€B€\€Ы”]Z]€


HO€›ЪY
OИВ€YЩ]ИY[ќU\™Щ]›Ы”]Z]HЫ”]Z]B€B€\€XШЩ\ЬЪXљ[]Q[X›Y›ЭљY\Ћ€


HO€›ЫЫ
OВ‚€љ]]H]љ[™ХљY]ИHљ[™Ф][ЭUљY]Књ[YN€”Ф™XЭ
€N€ЪY€‹ZYЪ€ЉJB€љ]]H]ЫЫ\[™[H][ЭUЫЫ\[™[

B€љ]]H]Y[ќU\™Щ]HY[ќPXЭ[Ы•\™Щ]

B€љ]]H\€][ЭN€][ЭHHќ[]Z[X›B€љ]]H\€Э™\•ЫЬљТ][N€\Ь]ЪЫЬљТ][OВ‚€[љ]

HВ€Э\\‹љ[љ]
€ЫЫќ[ќ™XЭ€”Ф™XЭ
€N€ЪY€‹ZYЪ€ЉK€Э[SX\ЪО€Л›Ь™\›\ЬЛ››ЫXЭ]][™Ф[™[K€XЪЪ[™О€ќY™™\™Y€Y™\Ћ€[ЩB€
B‚€\УЬ\]YHH[ЩB€XЪЩЬ›Э[™ЫЫЬ€HЫX\‚€\ФЪYЭИH[ЩB€]™[H™›Ш][™В€ЫЫXЭ[Ыђ™Z]љ[Ь€HЛШ[’›Ъ[ђ[ЬXЩ\Л™ќ[ШЬ™Y[ђ]^[X\ћKљYЫ›Ь™\РЮXЫWB€Y\УЫ‘XXЭ]]HH[ЩB€YЫ›Ь™\У[Э\ЩQ]™[ќИH[ЩB‚€љ[™ХљY]Л]]Ь™\Ъ^љ[™УX\ЪИHЛќЪYљZYЪB€љ[™ХљY]Л™њ[YHHЫЫќ[ќ™XЭ
›Ь‘њ[YT™XЭ€њ[YJB€љ[™ХљY]Л›Ы’Э™\€HИЭЩXZИЩ[—H[€Щ[ЏЛљ[™S[Э\ЩQ[ќ\Љ
HB€љ[™ХљY]Л›Ы’Э™\‘^]HИЭЩXZИЩ[—H[€Щ[ЏЛљ[™S[Э\ЩQ^]

HB€љ[™ХљY]ЛЫЫќ^Y[ќT›ЭљY\€HИЭЩXZИЩ[—H[€Щ[ЏЛ›XZЩPЫЫќ^Y[ќJ
HB€ЫЫќ[ќљY]ИHљ[™ХљY]В€B‚€Э™\њљYHќ[ИЬ™\“Э]
ИЩ[™\Ћ€[ћOКHВ€YUЫЫ\

B€Э\\‹›Ь™\“Э]
Щ[™\ЉB€B‚€Э™\њљYHќ[ИЩ]њ[YJИњ[YT™XЭ€”Ф™XЭ\Ь^H›YО€›ЫЫ
HВ€Э\\‹њЩ]њ[YJњ[YT™XЭ\Ь^N€›YКB€Y€ЫЫ\[™[љ\Хљ\ЪX›HВ€ЬЪ][Ы•ЫЫ\

B€B€B‚€ќ[И\]J][ЭN€][ЭJHВ€Щ[‹њ][ЭHH][ЭB€љ[™ХљY]Лњ][ЭHH][ЭB€ЫЫ\[™[ќ\]J^€][ЭHOHќ[]Z[X›HИ”™X[][ЭH[]Z[X›H€€][ЭKљЭ™\•^
B€B‚€љ]]Hќ[И[™S[Э\ЩQ[ќ\Љ
HВ€Ы’Э™\ЏК
B€Э™\•ЫЬљТ][OЛШ[Щ[

B‚€]][HH\Ь]ЪЫЬљТ][HИЭЩXZИЩ[—H[€Щ[ЏЛњЪЭХЫЫ\

HB€Э™\•ЫЬљТ][HH][B€\Ь]Ъ]Y]YK›XZ[‹\Ю[РYќ\ЉXY[™N€››ЭК
H
ИЊM‹^XЭ]N€][JB€B‚€љ]]Hќ[И[™S[Э\ЩQ^]

HВ€Э™\•ЫЬљТ][OЛШ[Щ[

B€Э™\•ЫЬљТ][HHљ[€YUЫЫ\

B€B‚€љ]]Hќ[ИЪЭХЫЫ\

HВ€ЭX\™\Хљ\ЪX›H[ЩHИ™]\›€B€ЫЫ\[™[ќ\]J^€][ЭHOHќ[]Z[X›HИ”™X[][ЭH[]Z[X›H€€][ЭKљЭ™\•^
B€ЬЪ][Ы•ЫЫ\

B€ЫЫ\[™[›Ь™\‘њ›Ыќ™YШ\™\ЬК
B€B‚€љ]]Hќ[ИYUЫЫ\

HВ€Э™\•ЫЬљТ][OЛШ[Щ[

B€Э™\•ЫЬљТ][HHљ[€ЫЫ\[™[›Ь™\“Э]
љ[
B€B‚€љ]]Hќ[ИЬЪ][Ы•ЫЫ\

HВ€ЭX\™]ШЬ™Y[€HШЬ™Y[€ПИ”ФШЬ™Y[‹›XZ[€[ЩHИ™]\›€B€]љ\ЪX›HHШЬ™Y[‹ќљ\ЪX›Qњ[YB€]Ъ^™HHЫЫ\[™[™њ[YKњЪ^™B‚€\€Hњ[YK›X^
И€\€HHњ[YK›ZYHHЪ^™KљZYЪИ‚‚€Y€
ИЪ^™KќЪY€љ\ЪX›K›X^H€В€Hњ[YK›Z[–HЪ^™KќЪYH€B€HHZ[ЉX^
Kљ\ЪX›K›Z[–H
ИЉKљ\ЪX›K›X^HHЪ^™KљZYЪHЉB‚€ЫЫ\[™[њЩ]њ[YSЬљYЪ[Љ”ФЪ[ќ
€N€JJB€B‚€љ]]Hќ[ИXZЩPЫЫќ^Y[ќJ
HO€”УY[ќHВ€]Y[ќHH”УY[ќJ]N€ђЪ]Ф][ЭHЭ™\›^HЉB‚€]™Yњ™\ЪH”УY[ќR][J]N€”™Yњ™\Ъ][ЭH›ЭИ‹XЭ[ЫЋ€ЬЩ[XЭЬЉY[ќPXЭ[Ы•\™Щ]њ™Yњ™\Ъ
ОЉJKЩ^Q\]Z][[ќ€€ЉB€™Yњ™\Ъќ\™Щ]HY[ќU\™Щ]€Y[ќKY][J™Yњ™\Ъ
B‚€]XШЩ\ЬЪXљ[]Q[X›YHXШЩ\ЬЪXљ[]Q[X›Y›ЭљY\ЏК
HПИ[ЩB€]XШЩ\ЬЪXљ[]U]HHXШЩ\ЬЪXљ[]Q[X›Y€И“]™HЪ[™ЭИXЪЪ[™О€Ы€‚€€‘[X›H]™HЪ[™ЭИXЪЪ[™ш )€‚€]XШЩ\ЬЪXљ[]HH”УY[ќR][J€]N€XШЩ\ЬЪXљ[]U]K€XЭ[ЫЋ€XШЩ\ЬЪXљ[]Q[X›YИљ[€ЬЩ[XЭЬЉY[ќPXЭ[Ы•\™Щ]њ™\]Y\ЭXШЩ\ЬЪXљ[]JОЉJK€Щ^Q\]Z][[ќ€€‚€
B€XШЩ\ЬЪXљ[]Kќ\™Щ]HXШЩ\ЬЪXљ[]Q[X›YИљ[€Y[ќU\™Щ]€XШЩ\ЬЪXљ[]Kљ\С[X›YHXXШЩ\ЬЪXљ[]Q[X›Y€Y[ќKY][JXШЩ\ЬЪXљ[]JB‚€Y[ќKY][JњЩ\\]ЬЉ
JB€]]Z]H”УY[ќR][J]N€”]Z]Ъ]Ф][ЭHЭ™\›^H‹XЭ[ЫЋ€ЬЩ[XЭЬЉY[ќPXЭ[Ы•\™Щ]њ]Z]
ОЉJKЩ^Q\]Z][[ќ€€ЉB€]Z]ќ\™Щ]HY[ќU\™Щ]€Y[ќKY][J]Z]
B‚€™]\›€Y[ќB€BџB