val ext_decode_compressed : bits(16) -> ast
function ext_decode_compressed(bv) = encdec_compressed(bv)

val ext_decode : bits(32) -> ast
function ext_decode(bv) = encdec(bv)