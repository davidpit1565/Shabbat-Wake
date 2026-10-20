# App Store images

Marketing images, 1320 × 2868 (6.9-inch iPhone), in five languages: `en`, `he`, `ru`, `fr`, `es`.

1. `1-home` — Never miss candle lighting again.
2. `5-editor` — An alarm that respects Shabbat.
3. `2-alarms` — Rings when it should. Stops by itself.
4. `3-times` — Exact times for where you are.
5. `6-widgets` — The next Shabbat time, right on your Home Screen.

How they are made: the app screens come from the "Screenshots" workflow, the widgets from the "Widget images" workflow
(the real widget views drawn in the simulator). `Scripts/appstore_images/compose_screens.py <screens dir> <out dir>` and
`compose_widgets.py <widget images dir> <out dir>` add the background, headline and frame.
