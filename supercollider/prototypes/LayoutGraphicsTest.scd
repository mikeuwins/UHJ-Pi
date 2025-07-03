(
// Layout Graphics Development - SuperCollider Drawing Code
// Developing graphics code to copy into main GUIPrototype.scd

var win, mainView, currentLayout = 0;
var layoutNames = ["QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON", "BINAURAL"];

win = Window("Layout Graphics Development", Rect(100, 100, 340, 320)).background_(Color.black);
mainView = CompositeView(win, Rect(0, 0, 340, 320)).background_(Color.black);

// Current layout name
~layoutLabel = StaticText(mainView, Rect(10, 10, 320, 25))
    .string_("Layout: " ++ layoutNames[currentLayout])
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

// Graphics canvas (320x275 to match LAYOUT overlay)
~canvas = UserView(mainView, Rect(10, 40, 320, 275))
    .background_(Color.black)
    .drawFunc_({ |view|
        var bounds = view.bounds;
        var centerX = bounds.width / 2;
        var centerY = bounds.height / 2;
        
        // GRAPHICS CODE FOR MAIN GUI - START
        // Set consistent pen width for everything
        Pen.width = 2;
        
        switch(currentLayout,
            0, {
                // QUAD SQUARE - Final version
                
                // Main square outline
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX - 90, centerY - 90, 180, 180));
                Pen.stroke;
                
                // ...existing code...
                
                // Front Left (top-left corner) - reference position - Speaker 1
                Pen.color = Color.black;
                Pen.addRect(Rect(centerX - 90 - 10, centerY - 90 - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX - 90 - 10, centerY - 90 - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("1", Point(centerX - 90 - 10 + 7, centerY - 90 - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Left (180 pixels down from reference) - Speaker 2
                Pen.color = Color.black;
                Pen.addRect(Rect(centerX - 90 - 10, centerY - 90 - 10 + 180, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX - 90 - 10, centerY - 90 - 10 + 180, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("2", Point(centerX - 90 - 10 + 7, centerY - 90 - 10 + 180 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Right (180 pixels right and 180 pixels down) - Speaker 3
                Pen.color = Color.black;
                Pen.addRect(Rect(centerX - 90 - 10 + 180, centerY - 90 - 10 + 180, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX - 90 - 10 + 180, centerY - 90 - 10 + 180, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("3", Point(centerX - 90 - 10 + 180 + 7, centerY - 90 - 10 + 180 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Front Right (180 pixels to the right) - Speaker 4
                Pen.color = Color.black;
                Pen.addRect(Rect(centerX - 90 - 10 + 180, centerY - 90 - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX - 90 - 10 + 180, centerY - 90 - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("4", Point(centerX - 90 - 10 + 180 + 7, centerY - 90 - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Descriptive text

                Pen.stringAtPoint("Equal distance between all speakers", Point(centerX - 97, 0), 
                                Font("Helvetica", 12), Color.cyan);
            },
            1, {
                // QUAD NARROW - Rectangle with width = 0.75 * height
                var rectHeight = 180;
                var rectWidth = (rectHeight * 0.75).asInteger; // 135 pixels
                var rectLeft = centerX - (rectWidth / 2); // Center horizontally
                var rectTop = centerY - (rectHeight / 2); // Center vertically
                
                // Main rectangle outline
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
                Pen.stroke;
                
                // All four speakers using the rectangle corners
                
                // Front Left (top-left corner) - Speaker 1
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Left (bottom-left corner) - Speaker 2
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Right (bottom-right corner) - Speaker 3
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Front Right (top-right corner) - Speaker 4
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);

            // Descriptive text

            Pen.stringAtPoint("Narrow Quadraphonic arrangement (x ≤ 0.75y)", Point(centerX - 115, 0), 
                                Font("Helvetica", 12), Color.cyan);                    
            },
            2, {
                // QUAD WIDE - Rectangle with vertical at 135px and horizontal at 180px
                
                var rectWidth = 180;
                var rectHeight = 135;
                var rectLeft = centerX - (rectWidth / 2);
                // Adjust vertical centering to account for speaker box extensions (10px each side)
                var totalHeight = rectHeight + 20; // rectangle + speaker extensions
                var rectTop = centerY - (totalHeight / 2) + 10; // +10 to account for top speaker extension
                
                // Main rectangle outline
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
                Pen.stroke;
                
                // All four speakers at rectangle corners
                
                // Front Left (top-left corner) - Speaker 1
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Left (bottom-left corner) - Speaker 2
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Back Right (bottom-right corner) - Speaker 3
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Front Right (top-right corner) - Speaker 4
                Pen.color = Color.black;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                Pen.stroke;
                Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);

            // Descriptive text

                Pen.stringAtPoint("Wide Quadraphonic arrangement (x ≥ 1.33y)", Point(centerX - 114, 0), 
                                Font("Helvetica", 12), Color.cyan);
            },
            3, {
                // DOLBY 5.1 - Standard Wikipedia layout
                
                var layoutSize = 180; // Main layout size (scaled down from 750px)
                var layoutLeft = centerX - (layoutSize / 2);
                var layoutTop = centerY - (layoutSize / 2);
                var speakerSize = 20; // Speaker box size
                var frontLeftX = layoutLeft - 10;
                var frontLeftY = layoutTop - 10;
                var frontRightX = layoutLeft + layoutSize - 10;
                var frontRightY = layoutTop - 10;
                var centerX_speaker = layoutLeft + (layoutSize / 2) - 10;
                var centerY_speaker = layoutTop - 10;
                var surroundLeftX = layoutLeft - 10;
                var surroundLeftY = layoutTop + layoutSize - 10;
                var surroundRightX = layoutLeft + layoutSize - 10;
                var surroundRightY = layoutTop + layoutSize - 10;
                var subwooferX = layoutLeft + (layoutSize / 2) - 10;
                var subwooferY = layoutTop + (layoutSize / 2) - 10;
                
                // Main layout rectangle outline
                Pen.color = Color.cyan;
                Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize));
                Pen.stroke;
                
                // Speaker 1: Front Left (top-left corner)
                Pen.color = Color.black;
                Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize));
                Pen.stroke;
                Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Speaker 2: Front Right (top-right corner)
                Pen.color = Color.black;
                Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize));
                Pen.stroke;
                Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Speaker 3: Center (top-center)
                Pen.color = Color.black;
                Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize));
                Pen.stroke;
                Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Speaker 4: Surround Left (bottom-left corner)
                Pen.color = Color.black;
                Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize));
                Pen.stroke;
                Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Speaker 5: Surround Right (bottom-right corner)
                Pen.color = Color.black;
                Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize));
                Pen.stroke;
                Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Subwoofer: (center, outline only like Wikipedia, labeled as 6 with SUB to the right)
                Pen.color = Color.cyan;
                Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize));
                Pen.stroke; // Only stroke, no fill (matches SVG fill-opacity="0")
                Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), 
                                Font("Helvetica", 10).boldVariant, Color.cyan);

            // Descriptive text

            Pen.stringAtPoint("[1] 0°, [2] -30°, [3] +30° [4] -110°, [5] +110°, [6] Sub", Point(centerX - 136, 0), 
                                Font("Helvetica", 12), Color.cyan); 
                                     
            },
            4, {
                // OCTAGON - 8 speakers arranged in octagonal pattern
                
                var radius = 100; // Distance from center to each speaker (increased from 80)
                var angleStep = 2 * pi / 8; // 45 degrees in radians
                var startAngle = -22.5 * pi / 180; // Start at 22.5 degrees anti-clockwise from 0 degrees (3 o'clock)
                
                // Calculate speaker positions in anti-clockwise order starting from 22.5 degrees
                var speakerPositions = Array.fill(8, { |i|
                    var angle = startAngle + (i * angleStep);
                    var x = centerX + (radius * cos(angle)) - 10; // -10 to center 20x20 speaker box
                    var y = centerY + (radius * sin(angle)) - 10; // -10 to center 20x20 speaker box
                    Point(x, y);
                });
                
                // Draw circle outline behind the speakers
                Pen.color = Color.cyan;
                Pen.addOval(Rect(centerX - radius, centerY - radius, radius * 2, radius * 2));
                Pen.stroke;
                
                // Draw speakers and numbers (anti-clockwise from 22.5 degrees)
                // Shift numbering so current position 7 becomes 1, 6 becomes 2, etc.
                speakerPositions.do({ |pos, i|
                    var speakerNum = ((i + 2) % 8) + 1; // Shift by 2 positions: 7->1, 6->2, 5->3, etc.
                    var angle = startAngle + (i * angleStep);
                    var rotationAngle = angle + (pi / 2); // Rotate 90 degrees to face center
                    
                    // Save current transform state
                    Pen.push;
                    
                    // Translate to speaker center, rotate, then translate back for drawing
                    Pen.translate(pos.x + 10, pos.y + 10); // Move to speaker center
                    Pen.rotate(rotationAngle); // Rotate to face center
                    Pen.translate(-10, -10); // Move back so rectangle draws centered
                    
                    // Speaker box (rotated to face center)
                    Pen.color = Color.black;
                    Pen.addRect(Rect(0, 0, 20, 20));
                    Pen.fill;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0, 0, 20, 20));
                    Pen.stroke;
                    
                    // Speaker number (also rotated)
                    Pen.stringAtPoint(speakerNum.asString, Point(7, 1), 
                                    Font("Helvetica", 12).boldVariant, Color.cyan);
                    
                    // Restore transform state
                    Pen.pop;
                });

           
           


            Pen.stringAtPoint("[1] -22.5°, Speakers @ 45°", Point(centerX - 69, 0), 
                                Font("Helvetica", 12), Color.cyan);

            },

            5, {
                // BINAURAL - Headphone representation matching the new clean SVG
                
                var earCupWidth = 24; // Width of each ear cup (made smaller)
                var earCupHeight = 32; // Height of each ear cup (made smaller)
                var earCupOffset = 65; // Distance from center to ear cup center (scaled up from 50)
                var arcCenterY = centerY - 30; // Moved down 10 pixels (was -40)
                var arcRadius = 55; // Larger radius (was 40)
                var leftEarX, leftEarY, rightEarX, rightEarY;
                
                // Left ear cup position (SVG: x="2" y="14")
                leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                leftEarY = centerY + 25; // Moved down 10 pixels (was +15)
                
                // Right ear cup position (SVG: x="16" y="14")  
                rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                rightEarY = centerY + 25; // Moved down 10 pixels (was +15)
                
                // Draw main headband arc (SVG path: semicircle from x=2 to x=22, center at x=12)
                // SVG: "M2,18V12A10,10,0,0,1,12,2h0A10,10,0,0,1,22,12v6"
                Pen.color = Color.cyan;
                Pen.width = 2;
                
                // Draw the main headband arc (semicircle from 180° to 0°)
                Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi);
                Pen.stroke;
                
                // Draw vertical connectors from arc to ear cups (like the SVG "V12" and "v6" parts)
                // Left connector
                Pen.moveTo(Point(centerX - arcRadius, centerY - 30));
                Pen.lineTo(Point(centerX - arcRadius, leftEarY));
                Pen.stroke;
                
                // Right connector
                Pen.moveTo(Point(centerX + arcRadius, centerY - 30));
                Pen.lineTo(Point(centerX + arcRadius, rightEarY));
                Pen.stroke;
                
                // Left ear cup (Speaker 1) - simple rectangle like SVG
                Pen.color = Color.black;
                Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.width = 2;
                Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                Pen.stroke;
                
                Pen.stringAtPoint("1", Point(leftEarX + 8, leftEarY + 7), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);
                
                // Right ear cup (Speaker 2) - simple rectangle like SVG
                Pen.color = Color.black;
                Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                Pen.fill;
                Pen.color = Color.cyan;
                Pen.width = 2;
                Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                Pen.stroke;
                
                Pen.stringAtPoint("2", Point(rightEarX + 8, rightEarY + 7), 
                                Font("Helvetica", 12).boldVariant, Color.cyan);

                // Descriptive text
                Pen.stringAtPoint("Headphone listening using IRCAM or CPIRC HTRF Libraries", Point(centerX - 153, 0), 
                                Font("Helvetica", 12), Color.cyan);
            }
        );
        
        // GRAPHICS CODE FOR MAIN GUI - END
        
    });

// Small navigation buttons at bottom corners
Button(mainView, Rect(10, 290, 30, 20))
    .states_([["<", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 8))
    .action_({
        currentLayout = (currentLayout - 1) % layoutNames.size;
        ~layoutLabel.string_("Layout: " ++ layoutNames[currentLayout]);
        ~canvas.refresh;
    });

Button(mainView, Rect(300, 290, 30, 20))
    .states_([[">", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 8))
    .action_({
        currentLayout = (currentLayout + 1) % layoutNames.size;
        ~layoutLabel.string_("Layout: " ++ layoutNames[currentLayout]);
        ~canvas.refresh;
    });

win.front;
)
