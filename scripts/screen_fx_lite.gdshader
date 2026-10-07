shader_type canvas_item;
render_mode unshaded;
// LIGHT display: the same pass without the bloom.
#define SCREEN_FX_LITE
#include "res://scripts/screen_fx.gdshaderinc"
