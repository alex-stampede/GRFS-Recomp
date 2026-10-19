import AppKit

private let grfsAccent = NSColor(srgbRed:0.49,green:0.91,blue:0.85,alpha:1)
final class GRFSBackdrop: NSView {
    private let artwork = Bundle.main.url(forResource:"Background",withExtension:"jpg").flatMap { NSImage(contentsOf:$0) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed:0.025,green:0.065,blue:0.09,alpha:1).setFill(); bounds.fill()
        if let artwork = artwork {
            let hero = NSRect(x:0,y:165,width:bounds.width,height:bounds.height-165)
            let scale = max(hero.width/artwork.size.width,hero.height/artwork.size.height)
            let size = NSSize(width:artwork.size.width*scale,height:artwork.size.height*scale)
            NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect:hero).addClip()
            artwork.draw(in:NSRect(x:hero.midX-size.width/2,y:hero.midY-size.height/2,width:size.width,height:size.height))
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGradient(colors:[NSColor(srgbRed:0.02,green:0.055,blue:0.08,alpha:1),NSColor.black.withAlphaComponent(0.08)])?.draw(in:bounds,angle:90)
        let panel = NSBezierPath(roundedRect:NSRect(x:28,y:28,width:bounds.width-56,height:182),xRadius:10,yRadius:10)
        NSColor(srgbRed:0.035,green:0.09,blue:0.12,alpha:0.95).setFill();panel.fill()
        grfsAccent.withAlphaComponent(0.18).setStroke();panel.lineWidth=1;panel.stroke()
        grfsAccent.setFill();NSRect(x:48,y:bounds.height-40,width:30,height:2).fill()
    }
}
final class GRFSProgressIndicator: NSProgressIndicator {
    override var intrinsicContentSize: NSSize { NSSize(width:NSView.noIntrinsicMetric,height:6) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.12).setFill();NSBezierPath(roundedRect:bounds,xRadius:3,yRadius:3).fill()
        let fraction = max(0,min(1,doubleValue/maxValue))
        if fraction > 0 { grfsAccent.setFill();NSBezierPath(roundedRect:NSRect(x:0,y:0,width:bounds.width*fraction,height:bounds.height),xRadius:3,yRadius:3).fill() }
    }
}
final class GRFSActionButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:5,yRadius:5)
        grfsAccent.withAlphaComponent(isEnabled ? (isHighlighted ? 0.7 : 1) : 0.25).setFill();shape.fill()
        let attributes: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:13,weight:.bold),.foregroundColor:NSColor(srgbRed:0.025,green:0.09,blue:0.12,alpha:1)]
        let text = title as NSString;let size = text.size(withAttributes:attributes)
        text.draw(at:NSPoint(x:bounds.midX-size.width/2,y:bounds.midY-size.height/2),withAttributes:attributes)
    }
}
extension Launcher {
    func buildWindow() {
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:600),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Ghost Recon Future Soldier Recomp"
        window.titlebarAppearsTransparent = true;window.titleVisibility = .hidden
        window.backgroundColor = NSColor(srgbRed:0.025,green:0.065,blue:0.09,alpha:1)
        window.appearance = NSAppearance(named:.darkAqua)
        NSApp.appearance = NSAppearance(named:.darkAqua)
        window.center();window.isReleasedWhenClosed=false
        let background = GRFSBackdrop();window.contentView = background
        func label(_ value:String,_ size:CGFloat,_ color:NSColor) -> NSTextField {
            let field = NSTextField(labelWithString:value);field.font = .monospacedSystemFont(ofSize:size,weight:.medium);field.textColor=color;return field
        }
        let brand = label("GRFS  //  RECOMP",13,grfsAccent)
        let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "Development"
        let platform = label("MACOS / ARM64     v\(version)",11,.white.withAlphaComponent(0.65))
        let section = label("MISSION PREPARATION",11,grfsAccent)
        let detail = label("LOCAL INSTALLATION  ·  SAVES & SHADER STORAGE PRESERVED",10,.white.withAlphaComponent(0.5))
        status.font = .systemFont(ofSize:17,weight:.medium);status.textColor = .white
        percent.font = .monospacedDigitSystemFont(ofSize:14,weight:.semibold);percent.textColor=grfsAccent
        bar.isIndeterminate=false;bar.minValue=0;bar.maxValue=100
        button.target=self;button.action=#selector(selectISO);button.isBordered=false
        for view in [brand,platform,section,status,percent,bar,detail,button] {
            view.translatesAutoresizingMaskIntoConstraints=false;background.addSubview(view)
        }
        NSLayoutConstraint.activate([
            brand.leadingAnchor.constraint(equalTo:background.leadingAnchor,constant:92),brand.topAnchor.constraint(equalTo:background.topAnchor,constant:31),
            platform.trailingAnchor.constraint(equalTo:background.trailingAnchor,constant:-48),platform.centerYAnchor.constraint(equalTo:brand.centerYAnchor),
            section.leadingAnchor.constraint(equalTo:background.leadingAnchor,constant:48),section.bottomAnchor.constraint(equalTo:background.bottomAnchor,constant:-179),
            status.leadingAnchor.constraint(equalTo:section.leadingAnchor),status.trailingAnchor.constraint(equalTo:background.trailingAnchor,constant:-100),status.topAnchor.constraint(equalTo:section.bottomAnchor,constant:13),
            bar.leadingAnchor.constraint(equalTo:section.leadingAnchor),bar.trailingAnchor.constraint(equalTo:background.trailingAnchor,constant:-48),bar.bottomAnchor.constraint(equalTo:background.bottomAnchor,constant:-107),bar.heightAnchor.constraint(equalToConstant:6),
            percent.trailingAnchor.constraint(equalTo:bar.trailingAnchor),percent.bottomAnchor.constraint(equalTo:bar.topAnchor,constant:-12),
            detail.leadingAnchor.constraint(equalTo:section.leadingAnchor),detail.bottomAnchor.constraint(equalTo:background.bottomAnchor,constant:-61),
            button.trailingAnchor.constraint(equalTo:bar.trailingAnchor),button.centerYAnchor.constraint(equalTo:detail.centerYAnchor),button.widthAnchor.constraint(equalToConstant:190),button.heightAnchor.constraint(equalToConstant:40)
        ])
        window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
}
