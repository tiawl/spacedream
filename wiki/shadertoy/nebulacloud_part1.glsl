# define BufferAChannel iChannel0
# define fontChannel    iChannel1
# define SPACE_CHAR 0x02U
# define STOP_CHAR  0x0AU

# define _How_to_make_this_ uvec4(0x84F677,   0x47F602D6, 0x16B656,   0x47869637)
# define _nebula_X_         uvec4(0xE6562657, 0xC61602F3, SPACE_CHAR, SPACE_CHAR)
# define _XX_Circles_       uvec4(0x13E20234, 0x962736C6, 0x5637,     SPACE_CHAR)
# define _Draw_a_circled_l_ uvec4(0x44271677, 0x02160236, 0x962736C6, 0x564602C6)
# define  _ight_            uvec4(0x96768647, SPACE_CHAR, SPACE_CHAR, SPACE_CHAR)
# define _Then_a_full_grid_ uvec4(0x458656E6, 0x02160266, 0x57C6C6,   0x76279646)
# define _Randomize_their_  uvec4(0x2516E646, 0xF6D696A7, 0x56024786, 0x569627)
# define _radius_           uvec4(0x27164696, 0x5737,     SPACE_CHAR, SPACE_CHAR)
# define _position_         uvec4(0x07F63796, 0x4796F6E6, SPACE_CHAR, SPACE_CHAR)
# define _Reduce_color_num_ uvec4(0x25564657, 0x36560236, 0xF6C6F627, 0x02E657D6)
# define _ber_              uvec4(0x265627,   SPACE_CHAR, SPACE_CHAR, SPACE_CHAR)
# define _Smooth_intersect_ uvec4(0x35D6F6F6, 0x47860296, 0xE6475627, 0x37563647)
# define _ions_             uvec4(0x96F6E637, SPACE_CHAR, SPACE_CHAR, SPACE_CHAR)
# define _Add_more_circles_ uvec4(0x144646,   0xD6F62756, 0x02369627, 0x36C65637)
# define _Increase_light_   uvec4(0x94E63627, 0x56163756, 0x02C69676, 0x8647)
# define _Apply_noisy_shap_ uvec4(0x140707C6, 0x9702E6F6, 0x963797,   0x37861607)
# define _e_                uvec4(0x56,       SPACE_CHAR, SPACE_CHAR, SPACE_CHAR)

# define FONT_NB int[](0x03, 0x13, 0x23, 0x33, 0x43, 0x53, 0x63, 0x73, 0x83, 0x93)

vec4 fontCol;vec3 fontColFill;vec3 fontColBorder;vec4 fontBuffer;vec2 fontCaret;float fontSize;float fontSpacing;vec2 fontUV;float log10(float x){if (x < 9.9999){return 0.;} else if (x < 99.9999) {return 1.;} else if (x < 999.9999) {return 2.;} else if (x < 9999.9999) {return 3.;} else if (x < 99999.9999) {return 4.;} else {return floor(log(x) / log(10.));}}vec4 fontTextureLookup(vec2 xy){float dxy = 1024.*1.5;vec2 dx = vec2(1.,0.)/dxy;vec2 dy = vec2(0.,1.)/dxy;return (texture(fontChannel,xy + dx + dy)+texture(fontChannel,xy + dx - dy)+texture(fontChannel,xy - dx - dy)+texture(fontChannel,xy - dx + dy)+2.*texture(fontChannel,xy))/6.;}void drawStr4(uint str){if (str < 0x100U){str = str * 0x100U + SPACE_CHAR;}if (str < 0x10000U){str = str * 0x100U + SPACE_CHAR;}if (str < 0x1000000U){str = str * 0x100U + SPACE_CHAR;}for (int i = 0; i < 4; i++){uint xy = (str >> 8 * (3 - i)) % 256U;if (xy != SPACE_CHAR){vec2 K = (fontUV - fontCaret) / fontSize;if (length(K) < 0.6){vec4 Q = fontTextureLookup((K + vec2(float(xy / 16U) + 0.5,16. - float(xy % 16U) - 0.5)) / 16.);fontBuffer.rgb += Q.rgb * smoothstep(0.6, 0.4, length(K));if (max(abs(K.x), abs(K.y)) < 0.5){fontBuffer.a = min(Q.a, fontBuffer.a);}}}if (xy != STOP_CHAR){fontCaret.x += fontSpacing * fontSize;}}}void beginDraw(){fontBuffer = vec4(0., 0., 0. , 1.);fontCol = vec4(0.);fontCaret.x += fontSpacing * fontSize / 2.;}void endDraw(){float a = smoothstep(1., 0., smoothstep(0.51, 0.53, fontBuffer.a));float b = smoothstep(0., 1., smoothstep(0.48, 0.51, fontBuffer.a));fontCol.rgb = mix(fontColFill, fontColBorder, b);fontCol.a = a;}void _(uint str){beginDraw();drawStr4(str);endDraw();}void _(uvec2 str){beginDraw();drawStr4(str.x);drawStr4(str.y);endDraw();}void _(uvec3 str){beginDraw();drawStr4(str.x);drawStr4(str.y);drawStr4(str.z);endDraw();}void _(uvec4 str){beginDraw();drawStr4(str.x);drawStr4(str.y);drawStr4(str.z);drawStr4(str.w);endDraw();}vec2 viewport(vec2 b){return (b / iResolution.xy - vec2(0.5)) * vec2(iResolution.x / iResolution.y, 1.);}

# define COLS 18.
# define COL_SEED 0u
# define SEED 1u
# define SWIRLS_RADIUS 0.5

float pixel_res;float pix;float time;const float depth = 1. / 360.;float floor2(float x, float base){return floor(x / base) * base;}float sdCircle(vec2 p, float r){return length(p) - r;}float opRing(vec2 p, float r1, float r2){return abs(sdCircle(p, r1)) - r2;}float sdSegment(vec2 p, vec2 a, vec2 b){vec2 pa = p - a;vec2 ba = b - a;float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);return length(pa - ba * h);}float smax(float a, float b, float k){float h = max(k - abs(a - b), 0.);return max(a, b) + h * h * 0.25 / k;}vec2 rotation(vec2 p, float a){return p * mat2(cos(a), -sin(a),sin(a), cos(a));}uvec3 pcg3d(uvec3 v){v = v * 1664525u + 1013904223u;v.x += v.y * v.z;v.y += v.z * v.x;v.z += v.x * v.y;v ^= v >> 16u;v.x += v.y * v.z;v.y += v.z * v.x;v.z += v.x * v.y;return v;}float hash(vec2 s, uint hash_seed){float res;uvec4 u = uvec4(s, uint(s.x) ^ uint(s.y), uint(s.x) + uint(s.y));uvec3 p = pcg3d(uvec3(u.x, u.y, hash_seed));res = float(p) * (1. / float(0xffffffffu));return res;}float circles(vec2 p, float r, float w, uint s){vec3 col;vec2 i = floor(p), f = fract(p), h;int k, q;float d = (sign(w) > -0.5 ? 8. : -1e9), c, rad, h2;for (k = -1; k < 2; k++){for (q = -1; q < 2; q++){p = vec2(k, q);h = vec2(hash(i + p, s + 89u), hash(i + p, s + 52u));c = length(p + h - f);if (sign(w) > -0.5){col = 0.5 + 0.5 * sin(hash(i + p, SEED + 32u) * 2.5 + 3.5 + vec3(2.));h2 = smoothstep(0., 1., 0.5 + 0.5 * (d - c) / w);d = mix(d, c, h2) - h2 * (1. - h2) * w / (1. + 3. * w);} else {rad = r / 2. + hash(i + p, s + 2u) * r;d = smax(d, rad - c, 0.3);}}}return (sign(w) > -0.5 ? 1. - d : d);}float fbmVoronoi(vec2 U, uint seed){float r = (circles(1.5 * U, -1., 0.3, seed)) * 0.625+ (circles(3. * U, -1., 0.3, seed + 314u)) * 0.25+ (circles(6. * U, -1., 0.3, seed + 92u)) * 0.125;return r;}float fbmCircles(vec2 p, uint se){float s = 1., d = 0.;int o = 2;for (int i = 0; i < o; i++){float n = s * circles(p, 0.5, -1., se);d = smax(d, n, 0.3 * s);p *= 2.;s = 0.5 * s;}return d;}vec2 swirls(vec2 p, uint se, float ro){vec2 i = round(p), d, cc;int k, q;float r, h;for (k = -1; k < 2; k++){for (q = -1; q < 2; q++){cc = i + vec2(k, q);d = cc + vec2(hash(cc, se + 222u), hash(cc, se + 278u)) - vec2(0.5);h = hash(cc, se + 72u)  * 2. - 1.;p -= d;r = ro * sign(h) * smoothstep(0., SWIRLS_RADIUS, (SWIRLS_RADIUS - length(p)) * abs(h));p = rotation(p, r) + d;}}return p;}vec2 fbmSwirls(vec2 p, uint se){uint o = 3u;float sz = 42., ro = 1.5;p *= 360. / sz;for (uint i = 0u; i < o; i++){p = swirls(p, se + i, ro);}return p / (360. / sz);}vec3 hsv2rgb(vec3 c){vec3 rgb = clamp(abs(mod(c.x * 6.+ vec3(0., 4., 2.), 6.) - 3.) - 1., 0., 1.);return c.z * mix(vec3(1.), rgb, c.y);}vec3 color(float sm, uint cseed){float var = 0.01 * sin(iTime * 50.);float hu, sa = 0., br = 0.;sa += var * 2.;hu = radians(6.2832 * (9. * hash(vec2(1.), cseed)+ sm * (hash(vec2(10.), cseed) * 0.25)));if (sm < 2.5){sa += 0.2 + 0.15 * sm;} else if (sm < 4.5) {sa += 0.35 + 0.1 * (sm - 2.);} else {sa += 0.55 - 0.07 * (sm - 4.);}if (sm < 3.5){br += 0.1 + 0.1 * sm;} else if (sm < 6.5) {br += 0.5 + 0.075 * (sm - 3.);} else {br += 0.7 + 0.1 * (sm - 6.);}return hsv2rgb(vec3(hu, sa, br));}

void nebula(vec2 u, out vec4 O)
{
  vec2 bU = 2.1 + (u - iResolution.xy * 0.5) / iResolution.y + time * 0.05;
  vec2 U = floor(bU * pix);
  bool dith = mod(U.x + U.y, 2.) < 1.;
  U /= pix;

  float fv = fbmVoronoi(U, SEED);
  vec2 aU = fbmSwirls(U, SEED) * 10.;
  float g = max(fbmCircles(aU, SEED + 10u), fbmCircles(aU, SEED + 20u));
  g = smax(-1., g, 3.2) * fv * fv;
  g *= (dith ? 1.35 : 1.5);

  g = floor(g * COLS) / COLS;
  O = vec4(color(10. * g, COL_SEED), 1.);
}

bool text(vec2 u, out vec4 O)
{
  bool b = false;
  O = vec4(0.);
  if (fontCol.w > 0.)
  {
    O = vec4((0.6 + 0.6 * cos(6.3 *
      ((u.x * 6. - iResolution.x * 0.25) / (3.14 * iResolution.y)) + vec4(0., 23., 21., 0.))
      * 0.85 + 0.15) * fontCol.x);
    b = true;
  }
  return b;
}

void mainImage(out vec4 O, vec2 u)
{
  pix = iResolution.y;
  vec2 v = viewport(u);
  fontSize = 0.075;
  fontSpacing = 0.45;
  fontUV = viewport(u);
  fontColFill = vec3(1.);
  fontColBorder = vec3(0.);
  uvec4 txt = uvec4(0x02020202);

  time = min(VIDEO_LENGTH, iTime + texelFetch(BufferAChannel, ivec2(u), 0).x);

  O = vec4(0.);

  fontCaret = vec2(-0.85, -0.45);
  float p = time * 10., power;
  float chars = log10(p) + 1.;
  int str = (p < 10. ? 0x020203E2 : 0x02020202), a = 0;
  while (chars > 0.5)
  {
    chars -= 1.;
    power = pow(10., chars);
    str = (str << 8) + FONT_NB[int(p / power)];
    if ((time * 10. >= 100. && a == 1) || (time * 10. >= 10. && time * 10. <= 100. && a == 0))
      str = (str << 8) + 0xE2;
    p = floor(mod(p, power));
    a++;
  }
  _(uvec3(str, 0xF22363E2, 0x03));
  if (text(u, O)) return;

  if (time < 4.)
  {
    fontSize = 0.1;
    if (v.y > 0.15)
    {
      fontCaret = vec2(-0.4, 0.2);
      txt = _How_to_make_this_;
    } else if (v.y > 0.) {
      fontCaret = vec2(-0.2, 0.1);
      txt = _nebula_X_;
    } else {
      fontCaret = vec2(-0.275, -0.15);
      txt = _XX_Circles_;
    }
  } else if (time < 6.) {
    if (v.x < -0.29)
    {
      fontCaret = vec2(-0.825, 0.4);
      txt = _Draw_a_circled_l_;
    } else {
      fontCaret = vec2(-0.29, 0.4);
      txt = _ight_;
    }
  } else if (time < 8.) {
    fontCaret = vec2(-0.825, 0.4);
    txt = _Then_a_full_grid_;
  } else if (time < 18.) {
    if ((time < 12.) || ((time > 13.) && (time < 17.)))
    {
      if (v.x < -0.29)
      {
        fontCaret = vec2(-0.825, 0.4);
        txt = (time < 12. ? _Randomize_their_ : (time < 15. ? _Reduce_color_num_ : _Smooth_intersect_));
      } else {
        fontCaret = vec2(-0.29, 0.4);
        txt = (time < 10. ? _radius_ : (time < 12. ? _position_ : (time < 15. ? _ber_ : _ions_)));
      }
    }
  } else if (time < 23.) {
    fontCaret = vec2(-0.825, 0.4);
    txt = (time < 20. ? _Add_more_circles_ : _Increase_light_);
  } else {
    if (v.x < -0.29)
    {
      fontCaret = vec2(-0.825, 0.4);
      txt = _Apply_noisy_shap_;
    } else {
      fontCaret = vec2(-0.29, 0.4);
      txt = _e_;
    }
  }

  _(txt);
  if (text(u, O)) { O *= (time > 3. && time < 4. ? (4. - time) * 0.5 :
    (time < 24. ? 1. : clamp(26. - time, 0., 1.))); return; }

  if (time < 4.)
  {
    pix = 150.;
    nebula(u, O);
    O *= (time > 3. ? (4. - time) * 0.5 : 1.);
  } else if (time < 6.) {
    vec2 U = (u - iResolution.xy * 0.5) / iResolution.y;
    O = vec4(vec3(0.5 - length(U)), 1.) * min(1., time - 4.);
  } else if (time < 8.) {
    vec2 U = (time > 6. ? min(1., (time - 6.) * 0.5) * 9. + 1. : 1.)
      * (u - iResolution.xy * 0.5) / iResolution.y;
    vec2 i = floor(U), f = fract(U), p = U;

    float d = 0., c;
    for (int k = -1; k < 2; k++)
    {
      for (int q = -1; q < 2; q++)
      {
        p = vec2(k, q) - f;

        c = 0.5 - length(p);
        d = max(d, c);
      }
    }
    O = vec4(vec3(max((7. - time), 0.) * (-length(U) + 0.5) + d * min(1., time - 6.)), 1.);
  } else if (time < 18.) {
    vec2 U = (time < 12. ? 10. * (2.1 + (u - iResolution.xy * 0.5) / iResolution.y) : 
      (time < 17. ? 21. + (max(0., 13. - time) * 7. + 3.) * (u - iResolution.xy * 0.5) / iResolution.y :
        21. + (min(1., time - 17.) * 7. + 3.) * (u - iResolution.xy * 0.5) / iResolution.y));
    uint seed = SEED + 10u;
    vec2 i = floor(U), f = fract(U), p = U, h;

    float d = 0., c, rad;
    for (int k = -1; k < 2; k++)
    {
      for (int q = -1; q < 2; q++)
      {
        p = vec2(k, q);
        rad = max((10. - time) * 0.5, 0.) * 0.5
          + (0.25 + hash(i + p, seed + 2u) * 0.5) * min(1., (time - 8.) * 0.5);
        h = clamp((time - 10.) * 0.5, 0., 1.) * vec2(hash(i + p, seed + 89u), hash(i + p, seed + 52u));
        p += h - f;

        c = rad - length(p);
        d = (time < 15. ? max(d, c) : smax(d, c, min(1., time - 15.) * 0.3));
      }
    }
    O = vec4(vec3(d), 1.);
    if (time > 13.)
    {
      float cols = max(0., 14. - time) * 100. + COLS;
      O = floor(O * cols) / cols;
    }
  } else if (time < 23.) {
    vec2 U = 10. * (2.1 + (u - iResolution.xy * 0.5) / iResolution.y);
    float g = max(fbmCircles(U, SEED + 10u), fbmCircles(U, SEED + 20u));
    O = vec4(vec3((time < 20. ? max(0., 0.5 * (20. - time)) * (circles(U, 0.5, -1., SEED + 10u))
      + min(1., (time - 18.) * 0.5) * g : max(0., 0.5 * (22. - time)) * g
      + min(1., (time - 20.) * 0.5) * smax(-1., g, 3.2 * min(1., (time - 20.) * 0.5)))), 1.);;
    O = floor(O * COLS) / COLS;
  } else {
    vec2 bU = 2.1 + (u - iResolution.xy * 0.5) / iResolution.y;
    vec2 U = 10. * bU;
    float fv = fbmVoronoi(bU, SEED);
    fv *= fv * 1.5;
    float g = max(fbmCircles(U, SEED + 10u), fbmCircles(U, SEED + 20u));
    g = smax(-1., g, 3.2);
    O = vec4(vec3(g * (min(1., time - 23.) * fv + max(0., 24. - time))), 1.);
    O = (floor(O * COLS) / COLS) * clamp(26. - time, 0., 1.);
  }
}
