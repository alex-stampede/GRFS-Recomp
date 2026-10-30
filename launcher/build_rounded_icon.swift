import AppKit
let source=CommandLine.arguments[1],out=CommandLine.arguments[2]
let im=NSImage(contentsOfFile:source)!
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
NSColor.clear.setFill();NSRect(x:0,y:0,width:1024,height:1024).fill()
let bounds=NSRect(x:48,y:48,width:928,height:928)
let shape=NSBezierPath(roundedRect:bounds,xRadius:205,yRadius:205)
shape.addClip();NSColor.black.setFill();shape.fill()
im.draw(in:bounds)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:out))
