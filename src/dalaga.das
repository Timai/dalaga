require assets
require daslib/media
require daslib/random

let
    TARGET_W = 480
    TARGET_H = 640

    PLAYER_W = 9
    PLAYER_H = 5
    PLAYER_SPD = 333.
    PLAYER_MAX_HEALTH = 10
    PLAYER_IMMORTAL_TIMER = 1.
    PLAYER_IMMORTAL_BLINKER_COUNT = 10
    PLAYER_IMMORTAL_BLINKER_SEG = PLAYER_IMMORTAL_TIMER / float(PLAYER_IMMORTAL_BLINKER_COUNT)

    MOB_STATIC_SPEED = 200.
    MOB_CHASER_SPEED = 75.

    STAGE_SPEED_SEG = 5.
    STAGE_SPEED_MUL = 0.5

    BKG_SCROLL_SPD = 20.
    COLLISION_DMG = 1
    FX_BULLET_COLLISION_LIFE = 0.15f

struct player_info
    pos : float2
    vel : float2 = float2( 0.f, 0.2 )
    rad : float = 12.f
    health : int = PLAYER_MAX_HEALTH
    guns : array<gun_info>
    gun_active : bool = false
    immortal_timer : float = 0.

struct mob_info
    t   : mob_type
    pos : float2
    vel : float2
    rad : float
    health : int
    score : int
    atl_idx : int
    speed : float
    guns : array<gun_info>

enum gun_type
    basic
    fast_rows
    super_rows
    radial
    mob_double
    mob_double_wide
    gun_type_count

enum mob_type
    scroller_dummy
    scroller_shooter
    chaser_shooter

struct gun_info
    dir   : float2
    pos   : float2
    rad   : float
    speed : float
    offset: float2
    timer : float
    timeout : float
    damage : int

struct scene
    player  : player_info
    bullets : array<bullet>
    mobs    : array<mob_info>
    powerups : array<powerup>
    effects  : array<fx_sprite>
    spawner : float
    bkg_scroll : float
    rnd_seed : int4
    score : int
    age : float

struct bullet
    pos : float2
    vel : float2
    rad : float
    dmg : int

struct powerup
    pos : float2
    gtype : gun_type
    timer : float = 5.
    rad = 10.

struct fx_sprite
    pos : float2
    rnd : int
    parts : int = 10
    size : float = 10.
    life : float = 0.

var
    g_screen_scale : int = 0
    g_screen_scale_max : int
    g_draw_debug : bool = false
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


def setup_gun( t : gun_type ; s : int ) : array<gun_info>
    var res : array<gun_info>
    var g : gun_info

    g.dir = float2( 0, 1 )
    g.timer = 0.

    if t == gun_type radial
        g.dir = float2( 0.4, 0.9 )
        g.offset = float2( 3., 5. ) * float( s )
        g.speed = 400.
        g.rad = 3.
        g.timeout = 0.1
        g.damage = 3
        push( res, g )
        g.offset.x = -3. * float( s )
        g.dir = float2( -0.4, 0.9 )
        push( res, g )
        g.offset.x = 0.
        g.dir = float2( 0, 1 )
        push( res, g )
    elif t == gun_type super_rows
        g.offset = float2( 4., 5. ) * float( s )
        g.speed = 400.
        g.rad = 2.
        g.timeout = 0.1
        g.damage = 2
        push( res, g )
        g.offset.x = -4. * float( s )
        push( res, g )
        g.offset.x = -8. * float( s )
        push( res, g )
        g.offset.x = 8. * float( s )
        push( res, g )
        g.offset.x = 0.
        push( res, g )
    elif t == gun_type fast_rows
        g.offset = float2( 3., 5. ) * float( s )
        g.speed = 400.
        g.rad = 1.
        g.timeout = 0.1
        g.damage = 1
        push( res, g )
        g.offset.x = -3. * float( s )
        push( res, g )
        g.offset.x = 0.
        push( res, g )
    elif t == gun_type mob_double
        g.dir = float2( 0, -1 )
        g.offset = float2( 2., -5. ) * float( s )
        g.speed = 100.
        g.rad = 1.5
        g.timeout = 1.
        g.damage = 1
        push( res, g )
        g.offset.x = -2. * float( s )
        push( res, g )
    elif t == gun_type mob_double_wide
        g.dir = float2( 0, -1 )
        g.offset = float2( 5., -5. ) * float( s )
        g.speed = 150.
        g.rad = 1.
        g.timeout = 0.75
        g.damage = 1
        push( res, g )
        g.offset.x = -5. * float( s )
        push( res, g )
    else
        g.offset = float2( .5, 5. ) * float( s )
        g.speed = 400.
        g.rad = 1.5
        g.timeout = 0.1
        g.damage = 1
        push( res, g )

    return <- res

def spawn_mob( pos : float ; t: mob_type )
    var m : mob_info
    m.t = t
    var gn = gun_type gun_type_count

    if t == mob_type scroller_shooter
        m.health = 5
        m.rad = 12.
        m.pos.x = pos
        m.vel = float2( 0, -1 ) * MOB_STATIC_SPEED
        m.score = 3
        m.atl_idx = 1
        gn = gun_type mob_double
    elif t == mob_type chaser_shooter
        m.health = 10
        m.rad = 12.
        m.pos.x = pos
        m.vel = float2( 0, -1 ) * MOB_STATIC_SPEED
        m.score = 10
        m.atl_idx = 2
        gn = gun_type mob_double_wide
    elif t == mob_type scroller_dummy
        m.health = 2
        m.rad = 12.
        m.pos.x = pos
        m.vel = float2( 0, -1 ) * MOB_STATIC_SPEED * 0.5
        m.score = 1
        m.atl_idx = 0
    if gn != gun_type gun_type_count
        m.guns <- setup_gun( gn, g_assets.mobs[m.atl_idx].scale )

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

    let reg_scaled = reg * g_screen_scale
    let rnd_ofs_limit = int2( reg - g_assets.stars.width, reg - g_assets.stars.height ) * g_screen_scale

    let bkg_offset = g_scene.bkg_scroll * float( g_screen_scale )

    for yy in range( -1, rows )
        let bkg_delta = bkg_offset % float( reg_scaled )
        let row = yy - int( bkg_offset / float( reg_scaled ) )
        var rnd_seed = int4( row, row, row, row )

        for xx in range( 0, cols )
            let rnd = random_int( rnd_seed )
            let rnd4 = random_int4( rnd_seed )

            let x = float( xx * reg_scaled + random_int( rnd_seed ) % rnd_ofs_limit.x )
            let y = float( yy * reg_scaled + random_int( rnd_seed ) % rnd_ofs_limit.y )
            let f = ( rnd % g_assets.stars.frames ) * g_assets.stars.width
            let fc = float( g_assets.stars.width )
            let c = 0xff000000 | uint( rnd4.x % 16 + 0 ) << 0x10 | uint( rnd4.y % 8 + 0 ) << 0x8 | uint( rnd4.y % 32 + 16 )
            let s = g_assets.stars.width * ( 1 + random_int( rnd_seed ) % g_screen_scale )

            if g_scene.player.health > 0
                draw_image_region( g_assets.stars.img, x, y + bkg_delta, float4( float( f ), 0., fc, fc ), c, float2( s, s ) )
            else
                fill_rect( xx * reg_scaled + 1, yy * reg_scaled + 1, reg_scaled - 2, reg_scaled - 2, c )


def wpos_to_spos( v : float2 ) : float2
    return float2( v.x, float( TARGET_H ) - v.y ) * float( g_screen_scale )

def draw_dyn_obj( img : Image ; wp : float2 ;  sz : float2 ; scale : int ; c : uint )
    let sp = wpos_to_spos( wp )
    let hss = float(g_screen_scale * scale) * 0.5
    draw_image_region( img, sp.x - sz.x *hss, sp.y - sz.y * hss, float4( 0., 0., sz.x, sz.y ), c, sz * float( g_screen_scale * scale ) )


def render_dyn()
    enable_alpha_blend()

    let w = float2( g_assets.player.width, g_assets.player.height )
    let blink = int( g_scene.player.immortal_timer / PLAYER_IMMORTAL_BLINKER_SEG ) % 2
    if blink == 0
        draw_dyn_obj( g_assets.player.img, g_scene.player.pos, float2(g_assets.player.width, g_assets.player.height), g_assets.player.scale, 0xffffffff )

    for b in g_scene.bullets
        let bp = wpos_to_spos( b.pos )
        fill_circle( bp.x, bp.y, b.rad * float( g_screen_scale ), 0xffffffff )

    for m in g_scene.mobs
        draw_dyn_obj( g_assets.mobs[m.atl_idx].img, m.pos, float2(g_assets.mobs[m.atl_idx].width, g_assets.mobs[m.atl_idx].height), g_assets.mobs[m.atl_idx].scale, 0xffffffff )

    for p in g_scene.powerups
        let bp = wpos_to_spos( p.pos )
        circle( bp.x, bp.y, p.rad * float( g_screen_scale ), 0xffffffff )
        if p.gtype == gun_type super_rows || p.gtype == gun_type radial
            circle( bp.x, bp.y, p.rad * 0.75 * float( g_screen_scale ), 0xff00ffff )
        if p.gtype == gun_type radial
            circle( bp.x, bp.y, p.rad * 0.5 * float( g_screen_scale ), 0xffffff00 )
        if p.gtype == gun_type gun_type_count
            circle( bp.x, bp.y, p.rad * 0.25 * float( g_screen_scale ), 0xffff0000 )

    for fx in g_scene.effects
        var seed = int4( fx.rnd, fx.rnd, fx.rnd, fx.rnd )
        for i in range( 0, fx.parts )
            var v = float2( random_float( seed ), random_float( seed ) )
            v -= float2( 0.5, 0.5 )
            let vl = length( v )
            if ( vl > FLT_MIN )
                v /= vl
            let l = fx.life / FX_BULLET_COLLISION_LIFE
            let p = wpos_to_spos( fx.pos + v * l * ( 5. + random_float( seed ) * fx.size * 0.5 ) )
            let d = wpos_to_spos( fx.pos + v * l * ( 10. + random_float( seed ) * fx.size ) )
            line( p.x, p.y, d.x, d.y, 0xffffffff )

    disable_alpha_blend()

def render_debug()
    if !g_draw_debug
        return

    var p = wpos_to_spos( g_scene.player.pos )
    circle( p.x, p.y, g_scene.player.rad * float( g_screen_scale ), 0xffffffff )

    for m in g_scene.mobs
        var mp = wpos_to_spos( m.pos )
        circle( mp.x, mp.y, m.rad * float( g_screen_scale ), 0xffff0000 )

    set_font_name( "mono" )
    set_font_size( 8 * g_screen_scale )
    let speed_mult = 1.f + ( g_scene.age / STAGE_SPEED_SEG ) * STAGE_SPEED_MUL

    let txt = "mobs: {length(g_scene.mobs)}
bullets: {length(g_scene.bullets)}
effects: {length(g_scene.effects)}
powerups: {length(g_scene.powerups)}

stage:{g_scene.age / STAGE_SPEED_SEG}
spawner_mul:{speed_mult}"
    text_out( 0, 0, txt, 0xffffffff )

def render_ui()
    let s = int2( 50, 10 )
    let ofs = int2( ( TARGET_W - s.x ) * g_screen_scale, ( TARGET_H - s.y ) * g_screen_scale )
    fill_rect( ofs.x, ofs.y, s.x * g_screen_scale, s.y * g_screen_scale, 0xffff0000 )
    fill_rect( ofs.x, ofs.y, int( float(s.x) * ( float(g_scene.player.health) / float(PLAYER_MAX_HEALTH) ) ) * g_screen_scale, s.y * g_screen_scale, 0xffffffff )

    set_font_name( "mono" )
    set_font_size( 10 * g_screen_scale )
    let score_text = "{g_scene.score}"
    var formated_score = ""
    for i in range( 0, 10 - length( score_text ) )
        formated_score += "0"
    formated_score += score_text

    let sw = get_text_size( formated_score )
    text_out( ( TARGET_W * g_screen_scale - int( sw.x ) ) / 2, 0, formated_score, 0xffffff00 )

    if g_scene.player.health <= 0
        let txt = "GAME OVER"
        set_font_size( 40 * g_screen_scale )
        let w = get_text_size( txt )
        text_out( ( TARGET_W * g_screen_scale - int( w.x ) ) / 2, ( TARGET_H * g_screen_scale - int( w.y ) ) / 2, txt, 0xffff0000 )

    set_font_size( 8 * g_screen_scale )
    let helper = "WASD/arr/mouse:move | shoot:space/LMB | pause:P | wnd scale:X | debug:O"
    let hs = int2( get_text_size( helper ) )
    text_out( 0, TARGET_H * g_screen_scale - hs.y, helper, 0xffffffff )

def process_gun( pos: float2 ; vel: float2 ; var guns: array<gun_info>& ; dt : float )
    for g in guns
        g.timer += dt
        while g.timer > g.timeout
            g.timer -= g.timeout
            var b : bullet
            b.pos = pos + g.offset
            b.rad = g.rad
            b.vel = g.dir * ( g.speed + max( vel.y * ( vel.y > 0. ? 1. : -1. ), 0. ) )
            b.dmg = g.damage
            push( g_scene.bullets, b )

def check_sphere_collision( p1 : float2 ; p2 : float2 ; r1 : float ; r2 : float ) : bool
    var rs = r1 + r2
    rs *= rs
    return rs >= length_sq( p1 - p2 )


def process_bullet_collision( pos : float2 ; rad : float ; player : bool ) : int
    var dmg = 0
    for b in g_scene.bullets
        let check = ( player && b.vel.y > 0. ) || ( !player && b.vel.y < 0. )
        if check && check_sphere_collision( pos, b.pos, rad, b.rad )
            dmg += b.dmg
            b.dmg = 0
    return dmg

def add_fx_sprite( pos : float2 ; parts : int = 0 ; size : float = 0. )
    var s = fx_sprite()
    s.pos = pos
    s.rnd = random_int( g_scene.rnd_seed )
    if ( parts > 0 )
        s.parts = parts
    if ( size > 0. )
        s.size = size
    push( g_scene.effects, s )

def process_act( dt: float )
    if g_paused || g_scene.player.health <= 0
        return
    g_scene.age += dt
    let speed_mult = 1.f + ( g_scene.age / STAGE_SPEED_SEG ) * STAGE_SPEED_MUL

    // player pos
    g_scene.player.pos += g_scene.player.vel * dt
    g_scene.player.pos.x = max( g_scene.player.pos.x, g_scene.player.rad )
    g_scene.player.pos.y = max( g_scene.player.pos.y, g_scene.player.rad )
    g_scene.player.pos.x = min( g_scene.player.pos.x, float(TARGET_W) - g_scene.player.rad )
    g_scene.player.pos.y = min( g_scene.player.pos.y, float(TARGET_H) - g_scene.player.rad )

    // guns
    if g_scene.player.gun_active
        process_gun( g_scene.player.pos, g_scene.player.vel, g_scene.player.guns, dt )

    // bullets
    for b in g_scene.bullets
        b.pos += b.vel * dt
        if b.pos.x < b.rad || b.pos.x > ( float(TARGET_W) - b.rad ) || b.pos.y < b.rad || b.pos.y > ( float(TARGET_H) - b.rad )
            b.dmg = 0

    var player_dmg = 0
    player_dmg = process_bullet_collision( g_scene.player.pos, g_scene.player.rad, false )
    if player_dmg > 0
        add_fx_sprite( g_scene.player.pos )

    for m in g_scene.mobs
        var dmg = process_bullet_collision( m.pos, m.rad, true )
        m.health -= dmg
        if dmg > 0 && m.health > 0
            add_fx_sprite( m.pos + float2( 0., -m.rad ) )
        if m.health <= 0
            g_scene.score += m.score
            add_fx_sprite( m.pos, 40, 40. )

            if random_float( g_scene.rnd_seed ) < 0.1
                var p = powerup()
                p.pos = m.pos
                let rnd = random_float( g_scene.rnd_seed )
                p.gtype = gun_type gun_type_count
                if rnd < 0.1
                    p.gtype = gun_type radial
                elif rnd < 0.3
                    p.gtype = gun_type fast_rows
                elif rnd < 0.8
                    p.gtype = gun_type super_rows

                push( g_scene.powerups, p )


    remove_if( g_scene.bullets ) <| $(v : bullet)
        return v.dmg <= 0

    // poweups
    for p in g_scene.powerups
        p.timer -= dt
        if ( p.timer > 0. )
            if check_sphere_collision( p.pos, g_scene.player.pos, p.rad, g_scene.player.rad )
                if p.gtype == gun_type gun_type_count
                    g_scene.player.health = min( g_scene.player.health + 1, PLAYER_MAX_HEALTH )
                else
                    g_scene.player.guns <- setup_gun( p.gtype, g_assets.player.scale )
                p.timer = 0.

    remove_if( g_scene.powerups ) <| $(v : powerup)
        return v.timer <= 0.

    // mobs
    var chasers : array<int>
    for i in range( 0, length( g_scene.mobs ) )
        var m& = g_scene.mobs[i]
        m.pos += m.vel * dt
        if ( m.pos.y - m.rad ) < 0.
            m.health = 0
        if m.health > 0
            if m.t == mob_type chaser_shooter
                if m.pos.y > g_scene.player.pos.y
                    push( chasers, i )
                else
                    m.vel.x = 0.
            process_gun( m.pos, m.vel, m.guns, dt )
            if check_sphere_collision( m.pos, g_scene.player.pos, m.rad, g_scene.player.rad )
                player_dmg += COLLISION_DMG

    for i in chasers
        var m& = g_scene.mobs[i]
        let v = m.pos.x - g_scene.player.pos.x
        m.vel.y = -MOB_CHASER_SPEED
        m.vel.x = 0.
        if ( v > 0. )
            m.vel.x = -MOB_CHASER_SPEED
        elif ( v < 0. )
            m.vel.x = MOB_CHASER_SPEED

    remove_if( g_scene.mobs ) <| $(v : mob_info)
        return v.health <= 0

    g_scene.spawner -= dt
    if ( g_scene.spawner <= 0. )
        g_scene.spawner = max( 1.f / speed_mult, 0.05f ) + random_float( g_scene.rnd_seed ) / speed_mult
        let rnd = random_float( g_scene.rnd_seed )
        var t = mob_type scroller_dummy
        if ( rnd < 0.1 )
            t = mob_type chaser_shooter
        elif ( rnd < 0.5 )
            t = mob_type scroller_shooter

        spawn_mob( random_float( g_scene.rnd_seed ) * float( TARGET_W ), t )

    // hp
    if g_scene.player.immortal_timer > 0.
        player_dmg = 0
    g_scene.player.health -= player_dmg
    g_scene.player.health = max( g_scene.player.health, 0 )
    if player_dmg > 0
        g_scene.player.guns <- setup_gun( gun_type basic, g_assets.player.scale )
        g_scene.player.immortal_timer = PLAYER_IMMORTAL_TIMER

    g_scene.player.immortal_timer = max( g_scene.player.immortal_timer - dt, 0. )

    // effects
    for fx in g_scene.effects
        fx.life += dt
    remove_if( g_scene.effects ) <| $(v : fx_sprite)
        return v.life >= FX_BULLET_COLLISION_LIFE

    g_scene.bkg_scroll += dt * BKG_SCROLL_SPD

def process_input()
    if g_scene.player.health <= 0 && ( get_key_up( VK_SPACE ) || get_mouse_button_up( MB_LEFT ) )
        reset()
        return

    var dx = float2( 0, 0 )
    dx.x += get_key( VK_RIGHT ) || get_key( VK_D ) ? +1. : 0.
    dx.x += get_key( VK_LEFT ) || get_key( VK_A ) ? -1. : 0.
    dx.y += get_key( VK_UP ) || get_key( VK_W ) ? +1. : 0.
    dx.y += get_key( VK_DOWN ) || get_key( VK_S ) ? -1. : 0.
    dx *= PLAYER_SPD

    let mx = get_mouse_velocity() * 2.
    dx += float2( mx.x, -mx.y )

    var dl = length( dx )
    if ( dl > FLT_MIN )
        dx /= dl
        dx *= min( dl, PLAYER_SPD )

    g_scene.player.vel = dx
    g_scene.player.gun_active = get_key( VK_SPACE ) || get_mouse_button( MB_LEFT )

def reinit()
    g_screen_scale = g_screen_scale == 0 ? g_screen_scale_max : g_screen_scale
    set_resolution( TARGET_W * g_screen_scale, TARGET_H * g_screen_scale )
    set_relative_mouse_mode(true)

def reset()
    g_scene.player := player_info()
    g_scene.player.pos = float2( float( TARGET_W / 2 ), g_scene.player.rad )
    g_scene.player.guns <- setup_gun( gun_type basic, g_assets.player.scale )
    g_scene.bkg_scroll = 0.
    g_scene.spawner = 1.
    g_scene.score = 0
    g_scene.age = 0.
    clear( g_scene.bullets )
    clear( g_scene.mobs )
    clear( g_scene.powerups )
    clear( g_scene.effects )
    randomize_seed( g_scene.rnd_seed )

[export]
def initialize
    set_window_title("dalaga")
    let h = float( get_desktop_height() ) * 0.95
    g_screen_scale_max = max( int( h / float(TARGET_H) ), 1 )
    reinit()
    setup_data()
    reset()

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_key_up(VK_T)
        reset()
    if get_key_up(VK_P)
        g_paused = ! g_paused
    if get_key_up(VK_O)
        g_draw_debug = !g_draw_debug
    if get_key_up(VK_X)
        g_screen_scale = ( g_screen_scale ) % ( g_screen_scale_max ) + 1
        reinit()
    process_input()
    process_act(dt)

[export]
def draw()
    render_bkg()
    render_ui()
    render_dyn()
    render_debug()