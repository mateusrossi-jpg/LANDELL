# Flutter Improve Design — Findings & Applied UI Redesign

**1. Don't let the system navigation bar cover the bottom of scrollable lists**

The last item of scrollable lists gets obscured by the system navigation bar. Leave space as tall as that bar at the end of the list so the last item has a breathing room against the bar.
Link: https://flutterpro.design/details/md/safe-area-replacement

**2. Make horizontal lists feel scrollable**

A horizontal scrollable list might not always signal that it's scrollable. Especially when the visible content just fits the view and no item is cut in half. Fading the edge hints users that there's more and they can scroll it.
Link: https://flutterpro.design/details/md/shader-mask

**3. Match text selection to your app's colors**

`MaterialApp` applies default tinted colors for text selection in inputs. Match them to your brand colors instead.
Link: https://flutterpro.design/details/md/selection-color

**4. Add haptic feedback to key moments**

The app feels flat when taps and results happen in silence. A subtle haptic vibration on a tab switch, a successful submit or an error makes the app feel responsive in the hand.
Link: https://flutterpro.design/details/md/haptic-feedback

**5. Use tabular figures for changing numbers**

Digits have different widths in most fonts, so a timer or counter jumps around as it changes. Tabular figures make every digit the same width: numbers stay still and line up.
Link: https://flutterpro.design/details/md/tabular-figures

**6. Dismiss the keyboard when the user scrolls**

The user finishes typing and scrolls to see the rest, but the keyboard stays covering half the screen. Scrolling means they're done with the field, so close it for them.
Link: https://flutterpro.design/details/md/dismiss-keyboard-on-scroll

**7. Make the whole GestureDetector area tappable**

By default `GestureDetector` only takes taps on what its child paints, so the padding and the gaps between an icon and a text do nothing. The user taps the row and misses. The whole box should take the tap.
Link: https://flutterpro.design/details/md/gesture-detector-hit-area

**8. Limit text scaling so layouts don't break**

Some users increase their device's text size for accessibility, and at high scales layouts overflow and break. After the fix, run the app at the capped scale yourself to confirm nothing breaks.
Link: https://flutterpro.design/details/md/text-scale-factor

**9. Show a friendly view when a widget breaks**

When a widget fails to build, users see an empty grey box in release. Show a friendly "Something went wrong" in the app's own colors instead.
Link: https://flutterpro.design/details/md/friendly-error-view
