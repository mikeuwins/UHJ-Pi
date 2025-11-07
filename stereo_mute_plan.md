## Stereo Layout Mute Follow-Up

- Update the stereo layout draw block so the left/right speaker boxes match the octagon mute styling (cyan when active, black when muted, grey inner border, cyan outline).
- Add `UserView` hit targets for both stereo boxes that toggle `~stereoState[\lOn]` / `~stereoState[\rOn]`, send the new values to `~synth`, and refresh the diagram.
- Add the grey inner border to the IRCAM and CIPIC headphone rectangles (same look as the octagon buttons).
- Rebuild/test on the Pi once the UI tweaks are in.


