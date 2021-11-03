require assets
require daslib/media
require daslib/random

let
    TARGET_W = 480
    TARGET_H = 640

    PLAYER_W = 9
    PLAYER_H = 5
    PLAYER_SPD = 333.

    BKG_SCROLL_SPD = 50.

struct player_info
    pos : float2
    vel : float2
    rad : float
    health : float
    guns : array<gun_info>
    gun_active : bool
    // immortal_timer : float

struct mob_info
    t   : mob_type
    pos : float2
    vel : float2
    rad : float
    health : float
    score : int
    guns : array<gun_info>

enum gun_type
    basic
    fast
    gun_type_count

enum mob_type
    scroller_dummy

struct gun_info
    dir   : float2
    pos   : float2
    rad   : float
    speed : float
    offset: float2
    timer : float
    timeout : float
    damage : float

struct scene
    player  : player_info
    bullets : array<bullet>
    mobs    : array<mob_info>
    spawner : float
    bkg_scroll : float
    rnd_seed : int4

struct bullet
    pos : float2
    vel : float2
    rad : float
    dmg : float

var
    g_screen_scale : int = 2
    g_screen_scale_max : int
    g_draw_debug : bool = true
    g_paused : bool = false

    g_assets : assets_lib
    g_scene : scene

def remove_if( var src ; cb )
    var idx = length( src ) - 1
    while idx >= 0
        if invoke( cb, src[idx] )
            src[idx] <- src[length(src) - 1]
            pop( src )
        idx--



def setup_gun( t : gun_type ) : array<gun_info>
    var res : array<gun_info>
    var g : gun_info
    g.dir = float2( 0, 1 )
    g.offset = float2( 0., 5. )
    g.speed = 4.
    g.timer = 0.
    g.rad = 2.5
    g.timeout = 0.1
    g.damage = 1.
    push( res, g )

    return <- res

def spawn_mob( pos : float ; t: mob_type )
    var m : mob_info
    m.t = t
    m.health = 5.
    m.rad = 10.
    m.pos.x = pos
    m.vel = float2( 0, -1 ) * 3.f
    m.score = 1

    m.pos.y = float( TARGET_H ) - m.rad
    m.pos.x = max( m.pos.x, m.rad )
    m.pos.x = min( m.pos.x, float( TARGET_W ) - m.rad  )

    emplace( g_scene.mobs, m )

def setup_data()
    g_assets <- setup_assets()


def render_bkg()
    let reg = 20
    let cols = TARGET_W / reg
    let rows = TARGET_H / reg

    fill_rect( 0, 0, get_screen_width(), get_screen_height(), 0x0 )

    var rnd_seed = int4( 1, 2, 3, 4 )

    let reg_scaled = reg * g_screen_scale
    let rnd_ofs_limit = int2( reg - g_assets.stars.width, reg - g_assets.stars.height ) * g_screen_scale

    let bkg_offset = g_scene.bkg_scroll * float( g_screen_scale )

    for yy in range( 0, rows )
        // let bkg_delta = bkg_offset % float( reg_scaled )
        let bkg_delta = 0. // TEMP

        for xx in range( 0, cols )
            let rnd = random_int4( rnd_seed )

            let x = float( xx * reg_scaled + rnd.x % rnd_ofs_limit.x )
            let y = float( yy * reg_scaled + rnd.y % rnd_ofs_limit.y )
            let f = ( rnd.z % g_assets.stars.frames ) * g_assets.stars.width
            let fc = float( g_assets.stars.width )
            let c = 0xff000000 | uint( rnd.x % 16 + 0 ) << 0x10 | uint( rnd.y % 8 + 0 ) << 0x8 | uint( rnd.w % 32 + 16 )
            let s = g_assets.stars.width * ( 1 + rnd.w % g_screen_scale )

            // fill_rect( xx * reg_scaled + 1, yy * reg_scaled + 1 + bkg_delta, reg_scaled - 2, reg_scaled - 2, c )
            draw_image_region( g_assets.stars.img, x, y + bkg_delta, float4( float( f ), 0., fc, fc ), c, float2( s, s ) )


def wpos_to_spos( v : float2 ) : float2
    return float2( v.x, float( TARGET_H ) - v.y ) * float( g_screen_scale )

def draw_dyn_obj( img : Image ; wp : float2 ;  sz : float2 ; c : uint )
    let sp = wpos_to_spos( wp )
    let hss = float(g_screen_scale) * 0.5
    draw_image_region( img, sp.x - sz.x *hss, sp.y - sz.y * hss, float4( 0., 0., sz.x, sz.y ), c, sz * float( g_screen_scale ) )


def render_dyn()
    let w = float2( g_assets.player.width, g_assets.player.height )
    draw_dyn_obj( g_assets.player.img, g_scene.player.pos, float2(g_assets.player.width, g_assets.player.height), 0xffffffff )

    for b in g_scene.bullets
        let bp = wpos_to_spos( b.pos )
        fill_circle( bp.x, bp.y, b.rad, 0xffffffff )


    for m in g_scene.mobs
        draw_dyn_obj( g_assets.player.img, m.pos, float2(g_assets.player.width, g_assets.player.height), 0xffff0000 )

def render_debug()
    if !g_draw_debug
        return

    var p = wpos_to_spos( g_scene.player.pos )
    circle( p.x, p.y, g_scene.player.rad * float( g_screen_scale ), 0xffffffff )

    for m in g_scene.mobs
        var mp = wpos_to_spos( m.pos )
        circle( mp.x, mp.y, m.rad * float( g_screen_scale ), 0xffff0000 )


def process_input()
    var dx = float2( 0, 0 )
    dx.x += get_key( VK_RIGHT ) || get_key( VK_D ) ? +1. : 0.
    dx.x += get_key( VK_LEFT ) || get_key( VK_A ) ? -1. : 0.
    dx.y += get_key( VK_UP ) || get_key( VK_W ) ? +1. : 0.
    dx.y += get_key( VK_DOWN ) || get_key( VK_S ) ? -1. : 0.

    // dx += get_mouse_velocity()

    var dl = length( dx )
    if ( dl > FLT_MIN )
        dx /= dl
    g_scene.player.vel = dx * PLAYER_SPD
    g_scene.player.gun_active = get_key( VK_SPACE ) || get_mouse_button_down( MB_LEFT )


def process_gun( pos: float2 ; var guns: array<gun_info>& ; dt : float )
    for g in guns
        g.timer += dt
        while g.timer > g.timeout
            g.timer -= g.timeout
            var b : bullet
            b.pos = pos + g.offset
            b.rad = g.rad
            b.vel = g.dir * g.speed
            b.dmg = g.damage
            push( g_scene.bullets, b )

def check_sphere_collision( p1 : float2 ; p2 : float2 ; r1 : float ; r2 : float ) : bool
    var rs = r1 + r2
    rs *= rs
    return rs >= length_sq( p1 - p2 )


def process_bullet_collision( pos : float2 ; rad : float ; player : bool ) : float
    var dmg = 0.
    for b in g_scene.bullets
        if check_sphere_collision( pos, b.pos, rad, b.rad )
            dmg += b.dmg
            b.dmg = 0.
    return dmg


def process_act( dt: float )
    if g_paused
        return

    // player pos
    g_scene.player.pos += g_scene.player.vel * dt
    g_scene.player.pos.x = max( g_scene.player.pos.x, g_scene.player.rad )
    g_scene.player.pos.y = max( g_scene.player.pos.y, g_scene.player.rad )
    g_scene.player.pos.x = min( g_scene.player.pos.x, float(TARGET_W) - g_scene.player.rad )
    g_scene.player.pos.y = min( g_scene.player.pos.y, float(TARGET_H) - g_scene.player.rad )

    // guns
    if g_scene.player.gun_active
        process_gun( g_scene.player.pos, g_scene.player.guns, dt )

    // bullets
    for b in g_scene.bullets
        b.pos += b.vel
        if b.pos.x < b.rad || b.pos.x > ( float(TARGET_W) - b.rad ) || b.pos.y < b.rad || b.pos.y > ( float(TARGET_H) - b.rad )
            b.dmg = 0.

    for m in g_scene.mobs
        m.health -= process_bullet_collision( m.pos, m.rad, false )

    remove_if( g_scene.bullets ) <| $(v : bullet)
        return v.dmg <= 0.

    // debug( "bullets:{length(g_scene.bullets)}" )

    // mobs
    for m in g_scene.mobs
        m.pos += m.vel
        if ( m.pos.y - m.rad ) < 0.
            m.health = 0.

    remove_if( g_scene.mobs ) <| $(v : mob_info)
        return v.health <= 0.

    g_scene.spawner -= dt
    if ( g_scene.spawner <= 0. )
        g_scene.spawner = 0.5f + random_float( g_scene.rnd_seed ) * 1.
        spawn_mob( random_float( g_scene.rnd_seed ) * float( TARGET_W ), mob_type scroller_dummy )

    debug( "mobs:{length(g_scene.mobs)}" );

    g_scene.bkg_scroll += dt * BKG_SCROLL_SPD

def reinit()
    g_screen_scale = g_screen_scale == 0 ? g_screen_scale_max : g_screen_scale
    set_resolution( TARGET_W * g_screen_scale, TARGET_H * g_screen_scale )

def reset()
    g_scene.player.rad = float( g_assets.player.width ) * 0.4
    g_scene.player.pos = float2( float( TARGET_W / 2 ), g_scene.player.rad )
    g_scene.player.gun_active = false
    clear( g_scene.player.guns ) // ????????????
    clear( g_scene.bullets )
    clear( g_scene.mobs )
    g_scene.player.guns <- setup_gun( gun_type basic )
    g_scene.player.health = 100.
    g_scene.bkg_scroll = 0.
    g_scene.spawner = 1.
    randomize_seed( g_scene.rnd_seed )

[export]
def initialize
    set_window_title("Playground")
    let h = float( get_desktop_height() ) * 0.95
    g_screen_scale_max = max( int( h / float(TARGET_H) ), 1 )
    reinit()
    setup_data()
    reset()

// def update_input()
//     let jump = get_key(VK_SPACE)

// def update_gameplay(dt: float)
//     update_bird(bird, dt)

[export]
def act(dt: float)
    // print("act dt={dt}\n")
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_key_up(VK_T)
        reset()
    if get_key_up(VK_P)
        g_paused = ! g_paused
    if get_key_up(VK_O)
        g_draw_debug = !g_draw_debug
    // if get_key(VK_X)
    //     g_screen_scale = ( g_screen_scale + 1 ) % ( g_screen_scale_max + 1 )
        reinit()
    process_input()
    process_act(dt)

[export]
def draw()
    render_bkg()
    render_dyn()
    render_debug()
