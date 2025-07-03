// Quick test to verify LAYOUT overlay border is visible

(
var win, mainView, layoutOverlay;

win = Window("Layout Border Test", Rect(100, 100, 400, 350)).background_(Color.black);
mainView = CompositeView(win, Rect(0, 0, 400, 350)).background_(Color.black);

// Create a layout overlay with the same structure as the fixed main GUI
layoutOverlay = View(mainView, Rect(40, 40, 320, 275))
    .background_(Color.black);

// Border UserView (same as EQ/Ambience)
UserView(layoutOverlay, Rect(0, 0, 320, 275))
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
        Pen.stroke;
    });

// Title
StaticText(layoutOverlay, Rect(10, 5, 300, 22))
    .string_("LAYOUT - QUAD SQUARE")
    .align_(\left)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 12).boldVariant)
    .background_(Color.clear);

// Graphics canvas with fixed positioning and clear background
UserView(layoutOverlay, Rect(10, 30, 300, 235))
    .background_(Color.clear)
    .drawFunc_({ |view|
        var bounds = view.bounds;
        var centerX = bounds.width / 2;
        var centerY = bounds.height / 2;
        
        // Fill background with black
        Pen.color = Color.black;
        Pen.addRect(Rect(0, 0, bounds.width, bounds.height));
        Pen.fill;
        
        // Draw a simple test layout - QUAD SQUARE
        Pen.width = 2;
        Pen.color = Color.cyan;
        
        var speakerSize = 20;
        var distance = 60;
        var positions = [
            [centerX - distance, centerY - distance], // Top-left (FL)
            [centerX + distance, centerY - distance], // Top-right (FR)
            [centerX + distance, centerY + distance], // Bottom-right (BR)
            [centerX - distance, centerY + distance]  // Bottom-left (BL)
        ];
        var labels = ["1", "2", "3", "4"];
        
        positions.do({ |pos, i|
            // Draw speaker box
            Pen.addRect(Rect(pos[0] - speakerSize/2, pos[1] - speakerSize/2, speakerSize, speakerSize));
            Pen.stroke;
            
            // Draw label
            Pen.stringCenteredIn(labels[i], 
                Rect(pos[0] - speakerSize/2, pos[1] - speakerSize/2, speakerSize, speakerSize),
                Font("Helvetica", 12).boldVariant, Color.cyan);
        });
    });

// Close button
Button(layoutOverlay, Rect(222, 275, 80, 28))
    .states_([["CLOSE", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 11))
    .action_({ win.close; });

win.front;
)
