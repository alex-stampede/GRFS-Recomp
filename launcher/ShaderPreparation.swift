import AppKit
import QuartzCore

final class ShaderPreparation {
    var progressWindow:NSWindow?
    var progressLabel:NSTextField?
    var progressBar:NSProgressIndicator?
    var progressTimer:Timer?
    var prepStarted=Date()
    var preparationIPC:URL?
    var process:Process?
    func stop(){progressTimer?.invalidate();progressTimer=nil;progressWindow?.orderOut(nil);process=nil}
    func showPreparation(_ folder:URL){
        let win=NSPanel(contentRect:NSRect(x:0,y:0,width:560,height:190),styleMask:[.titled,.nonactivatingPanel],backing:.buffered,defer:false)
        win.backgroundColor=NSColor(calibratedRed:0.025,green:0.05,blue:0.065,alpha:1);win.titlebarAppearsTransparent=true
        win.title="GRFS — Preparando gráficos";win.appearance=NSAppearance(named:.darkAqua);win.center();win.level = .statusBar;win.hidesOnDeactivate=false;win.isFloatingPanel=true
        win.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications]
        let title=NSTextField(labelWithString:"GHOST RECON // GRAPHICS PREPARATION")
        title.font = .monospacedSystemFont(ofSize:17,weight:.bold);title.textColor = .systemTeal;title.frame=NSRect(x:24,y:130,width:520,height:30)
        let text=NSTextField(wrappingLabelWithString:"Iniciando el backend gráfico…")
        text.textColor = NSColor(calibratedWhite:0.9,alpha:1)
        text.frame=NSRect(x:24,y:73,width:510,height:48)
        let bar=NSProgressIndicator(frame:NSRect(x:24,y:40,width:510,height:18));bar.isIndeterminate=true;bar.style = .bar;bar.startAnimation(nil)
        let note=NSTextField(labelWithString:"Primera apertura: aprende variantes. Siguientes: prepara las conocidas.")
        note.textColor = .systemTeal
        note.font = .systemFont(ofSize:11);note.frame=NSRect(x:24,y:12,width:520,height:18)
        for v in [title,text,bar,note] as [NSView]{win.contentView?.addSubview(v)}
        progressWindow=win;progressLabel=text;progressBar=bar;prepStarted=Date();win.orderFrontRegardless()
        let timer=Timer(timeInterval:0.2,repeats:true){[weak self] _ in
            guard let self=self else{return}
            // Follow the actual game window, including another display/fullscreen Space.
            if let pid=self.process?.processIdentifier, let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID)as? [[String:Any]],let game=windows.first(where:{($0[kCGWindowOwnerPID as String]as? NSNumber)?.int32Value==pid && (($0[kCGWindowLayer as String]as? NSNumber)?.intValue ?? 0)==0}),let bounds=game[kCGWindowBounds as String]as? [String:Any],let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary){
                let desktopTop=NSScreen.screens.first?.frame.maxY ?? rect.maxY
                let center=NSPoint(x:rect.midX,y:desktopTop-rect.midY)
                self.progressWindow?.setFrameOrigin(NSPoint(x:center.x-280,y:center.y-95))
            }
            self.progressWindow?.orderFrontRegardless()
            let path=self.preparationIPC ?? folder.appendingPathComponent("prewarm.json")
            // Independent completion signals prevent a stranded progress panel if IPC fails.
            func tail(_ name:String)->String {
                guard let f=try? FileHandle(forReadingFrom:folder.appendingPathComponent(name)) else{return ""};defer{try? f.close()}
                guard let end=try? f.seekToEnd() else{return ""};try? f.seek(toOffset:end>16384 ? end-16384:0)
                return String(data:(try? f.readToEnd()) ?? Data(),encoding:.utf8) ?? ""
            }
            let audit=tail("pipeline-audit.jsonl")
            let log=tail("game.log")
            let traceSize=((try? fm.attributesOfItem(atPath:folder.appendingPathComponent("guest-swaps.txt").path)[.size])as? NSNumber)?.intValue ?? 0
            if audit.contains("\"phase\":\"game\"") || log.contains("[GRFS PREWARM] ready:") || traceSize>0 {
                self.progressTimer?.invalidate();self.progressWindow?.orderOut(nil);return
            }
            guard let data=try? Data(contentsOf:path),let json=(try? JSONSerialization.jsonObject(with:data))as? [String:Any],let phase=json["phase"]as? String else{
                if Date().timeIntervalSince(self.prepStarted)>15 {self.progressLabel?.stringValue="Inicializando gráficos… La primera preparación puede tardar. El juego sigue arrancando."};return
            }
            let done=(json["done"]as? NSNumber)?.doubleValue ?? 0,total=(json["total"]as? NSNumber)?.doubleValue ?? 0
            let fraction=total>0 ? min(1,done/total):0
            var value=0.0;var status="Revisando la caché compatible…"
            if phase=="shaders"{value=20*fraction;status="Traduciendo shaders conocidos: \(Int(done)) / \(Int(total))"}
            if phase=="pipelines"{value=20+80*fraction;status="Preparando pipelines conocidos: \(Int(done)) / \(Int(total))"}
            if phase=="ready"{value=100;status=total>0 ? "Preparación terminada. Abriendo el juego…":"Sin pipelines conocidos aún. Se registrarán mientras juegas."}
            self.progressBar?.stopAnimation(nil);self.progressBar?.isIndeterminate=false;self.progressBar?.doubleValue=value
            let elapsed=Int(Date().timeIntervalSince(self.prepStarted))
            self.progressLabel?.stringValue="\(Int(value))% — \(status)\nTiempo transcurrido: \(elapsed) s"
            if phase=="ready"{
                self.progressTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline:.now()+0.7){self.progressWindow?.orderOut(nil);if let pid=self.process?.processIdentifier{NSRunningApplication(processIdentifier:pid)?.activate(options:[])} }
            }
        }
        RunLoop.main.add(timer,forMode:.common);progressTimer=timer
    }

}
