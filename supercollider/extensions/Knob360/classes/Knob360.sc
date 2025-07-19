Knob360 : UserView {
    var <value, <action, <minval, <maxval, <colors;

    *new { |parent, bounds, value=0.0, minval=0.0, maxval=1.0, action|
        var instance = super.new(parent, bounds);
        instance.minval = 0.0;
        instance.maxval = 1.0;
        instance.value = (value ? 0.0).asFloat;
        instance.action = action;
        instance.colors = [Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan]; // default colors
        instance.drawFunc = { |view, handle|
            var center = Point(view.bounds.width/2, view.bounds.height/2);
            var radius = (view.bounds.width.min(view.bounds.height) * 0.45);
            var angle = (view.value * (2 * pi)) + (pi/2); // 0 is up
            // Outer filled knob base
            Pen.color = view.colors[0]; // background color
            Pen.addOval(Rect(center.x - radius, center.y - radius, radius*2, radius*2));
            Pen.fill;
            // Outer cyan arc
            Pen.color = view.colors[2]; // border color
            Pen.width = 4;
            Pen.addArc(center, radius, 0, 2 * pi);
            Pen.stroke;
            // Pointer with rounded ends to match original knobs
            handle = center + Point(radius * 0.6 * angle.cos, radius * 0.6 * angle.sin);
            Pen.color = view.colors[3]; // pointer color
            Pen.width = 4;
            // Draw the main pointer line
            Pen.moveTo(center); 
            Pen.lineTo(handle); 
            Pen.stroke;
            // Draw rounded ends with small circles
            Pen.addOval(Rect(center.x - 2, center.y - 2, 4, 4));
            Pen.fill;
            Pen.addOval(Rect(handle.x - 2, handle.y - 2, 4, 4));
            Pen.fill;
        };
        instance.mouseDownAction = { |view, x, y, mod, button, count| instance.doMouse(x, y); };
        instance.mouseMoveAction = { |view, x, y, mod| instance.doMouse(x, y); };
        instance.mouseUpAction = { |view, x, y, mod, button, count| };
        ^instance;
    }

    doMouse { |x, y, dx, dy, angle|
        var center = Point(this.bounds.width/2, this.bounds.height/2);
        dx = x - center.x; dy = y - center.y;
        angle = atan2(dy, dx);
        value = ((angle - (pi/2)) / (2 * pi));
        if(value < 0) { value = value + 1; };
        value = value.clip(0.0, 1.0);
        if(action.notNil) { action.value(this, value); };
        this.refresh;
    }
    value_ { |v| value = (v ? 0.0).asFloat.clip(0.0, 1.0); this.refresh; }
    valueAction_ { |v| value = (v ? 0.0).asFloat.clip(0.0, 1.0); if(action.notNil) { action.value(this, value); }; this.refresh; }
    action_ { |a| action = a; }
    minval_ { |m| minval = 0.0; this.refresh; }
    maxval_ { |m| maxval = 1.0; this.refresh; }
    color_ { |c| colors = c; this.refresh; }
    colors_ { |c| colors = c; this.refresh; }
} 