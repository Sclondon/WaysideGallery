class_name ArtPiece
extends RefCounted
## One artwork: what the catalog says about it, and where the gallery hung it.

var file := ""
var texture: Texture2D
var title := ""
var artist := ""
var year := ""
var medium := ""
var description := ""
var frame := ""           ## "black", "walnut", "oak", "gold", "white" or "none"
var width_m := 1.0        ## size of the picture itself, before any wall-fit scaling
var height_m := 1.0

# Filled in by Gallery when the piece is hung.
var index := -1
var center := Vector3.ZERO    ## middle of the picture surface, world space
var normal := Vector3.BACK    ## direction the picture faces (out of the wall)
var outer_size := Vector2.ONE ## picture plus frame, as hung
var clearance := 10.0         ## open floor in front of the wall, metres
