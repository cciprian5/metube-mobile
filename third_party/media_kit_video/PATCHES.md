# media_kit_video 2.0.1, patched

A copy of [media_kit_video](https://pub.dev/packages/media_kit_video) 2.0.1
(MIT, see `LICENSE`), used by the Windows app through `dependency_overrides`
in the workspace `pubspec.yaml`. The `example/` folder and the
`analysis_options.yaml` of the original are left out. Only
`windows/video_output.cc` changed; the Dart API is the same.

## The change: a frame asked for while the texture is being replaced

When a clip with other dimensions starts, `VideoOutput::Resize` registers a
new texture, stores its id in `texture_id_`, and only afterwards adds the
texture to `textures_` (or `pixel_buffer_textures_`). The frame callback the
engine calls on its raster thread looked the id up with `at`. A frame asked
for between those two steps found no entry, and `at` threw
`std::out_of_range`.

The engine calls that callback inside a `noexcept` function, so the throw
ended the process at once (`terminate`, then `abort`, then `0xC0000409`
with no message). Two crash dumps from a real machine show exactly this
stack: the texture layer, `ExternalTextureD3d`, the plugin's callback,
`std::_Xout_of_range`, `_CxxThrowException`, `terminate`. Both followed the
opening of a clip whose size differed from the one before.

The patch looks the id up with `find` in the two frame callbacks and in the
two software-rendering reads of the same maps. An id with no texture yet
gives no frame this time; the next frame, a moment later, finds it.
