module assets

require daslib/media

struct atls_stars
    img : Image
    width : int
    height : int
    frames : int

struct atls_dyn
    img : Image
    width : int
    height : int
    frames : int
    scale : int

struct assets_lib
    stars: atls_stars
    player: atls_dyn
    mobs : atls_dyn[3]

def private setup_stars() : atls_stars
    var res : atls_stars
    res.width = 9
    res.height = 9
    res.frames = 3
    res.img <- create_image( res.width * res.frames, res.height,
    "    #    " + "    #    " + "    @    " +
    "   @#@   " + "   @#@   " + "   @@@   " +
    "  @###@  " + "  @###@  " + "  @@@@@  " +
    " @#####@ " + " @##@##@ " + " @@@#@@@ " +
    "#########" + "###@@@###" + "@@@###@@@" +
    " @#####@ " + " @##@##@ " + " @@@#@@@ " +
    "  @###@  " + "  @###@  " + "  @@#@@  " +
    "   @#@   " + "   @#@   " + "   @@@   " +
    "    #    " + "    #    " + "    @    ",
    {{ ' ' => 0x0; '#' => 0xffffffff; '@' => 0xff777777 }} )
    return <- res

def private setup_player() : atls_dyn
    var res  : atls_dyn
    res.width = 17
    res.height = 8
    res.frames = 1
    res.scale = 2

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

def private setup_mob_type_0() : atls_dyn
    var res  : atls_dyn
    res.width = 15
    res.height = 7
    res.frames = 1
    res.scale = 2

    res.img <- create_image( res.width * res.frames, res.height,
    "@#############@" +
    " @#####$#####@ " +
    "  @####$####@  " +
    "   @###$###@   " +
    "    @##$##@    " +
    "     @###@     " +
    "      @#@      ",
    {{ ' ' => 0x0; '#' => 0xffffffff; '@' => 0xff777777; '$' => 0xffff0000 }} )
    return <- res

def private setup_mob_type_1() : atls_dyn
    var res  : atls_dyn
    res.width = 15
    res.height = 7
    res.frames = 1
    res.scale = 2

    res.img <- create_image( res.width * res.frames, res.height,
    "@#############@" +
    " @#####$#####@ " +
    "  @####$####@  " +
    "   @###$###@   " +
    "    ###$###    " +
    "    #@###@#    " +
    "    # @#@ #    ",
    {{ ' ' => 0x0; '#' => 0xffeeee77; '@' => 0xffcccc77; '$' => 0xffff0000 }} )
    return <- res

def private setup_mob_type_2() : atls_dyn
    var res  : atls_dyn
    res.width = 13
    res.height = 6
    res.frames = 1
    res.scale = 2

    res.img <- create_image( res.width * res.frames, res.height,
    "   @@@@@@@   " +
    "  @#######@  " +
    "@###@@@@@###@" +
    "@##@@@@@@@##@" +
    "@##@@   @@##@" +
    "@##@     @##@",
    {{ ' ' => 0x0; '#' => 0xffff3333; '@' => 0xff770000; '$' => 0xffff0000 }} )
    return <- res


def setup_assets() : assets_lib
    var lib : assets_lib

    lib.stars <- setup_stars()
    lib.player <- setup_player()
    lib.mobs[0] <- setup_mob_type_0()
    lib.mobs[1] <- setup_mob_type_1()
    lib.mobs[2] <- setup_mob_type_2()

    return <- lib