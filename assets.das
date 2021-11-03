module assets

require daslib/media

struct atls_stars
    img : Image
    width : int
    height : int
    frames : int

struct atls_player
    img : Image
    width : int
    height : int
    frames : int

struct assets_lib
    stars: atls_stars
    player: atls_player

def private setup_stars() : atls_stars
    var res : atls_stars
    res.width = 9
    res.height = 9
    res.frames = 2
    res.img <- create_image( res.width * res.frames, res.height,
    "    #    " + "    #    " +
    "   @#@   " + "   @#@   " +
    "  @###@  " + "  @###@  " +
    " @#####@ " + " @##@##@ " +
    "#########" + "###@@@###" +
    " @#####@ " + " @##@##@ " +
    "  @###@  " + "  @###@  " +
    "   @#@   " + "   @#@   " +
    "    #    " + "    #    ",
    {{ ' ' => 0x0; '#' => 0xffffffff; '@' => 0xff777777 }} )
    return <- res

def private setup_player() : atls_player
    var res  : atls_player
    res.width = 17
    res.height = 8
    res.frames = 1

    res.img <- create_image( res.width * res.frames, res.height,
    "        @        " +
    "       @#@       " +
    "     #@#$#@#     " +
    "     ###$###     " +
    "    @###$###@    " +
    "  @#####@#####@  " +
    " @####@@@@@####@ " +
    " @@@@@@   @@@@@@ ",
    {{ ' ' => 0x0; '#' => 0xffffffff; '@' => 0xff777777; '$' => 0xff0000ff }} )
    return <- res

def setup_assets() : assets_lib
    var lib : assets_lib

    lib.stars <- setup_stars()
    lib.player <- setup_player()

    return <- lib