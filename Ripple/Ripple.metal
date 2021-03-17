//
//  Ripple.metal
//  Ripple
//
//  Created by Laszlo Nagy on 14/03/2021.
//

//comment this, if you want to see my first attempt.
//It was ugly, but was simple and worked like a charm
#define FANCY

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float3 normalizedPosition;
    float2 texcoord;
} RasterizerData;

typedef struct {
    float time;
    float2 origin;
} RippleData;

constant constexpr static const float4 fullscreenTrianglePositions[3]
{
    {-1.0, -1.0, 0.0, 1.0},
    { -1.0, 3.0, 0.0, 1.0},
    {3.0, -1.0, 0.0, 1.0}
};

vertex RasterizerData rippleVertex(unsigned int id [[vertex_id]])
{
    RasterizerData out;
    out.position = fullscreenTrianglePositions[id];
    out.normalizedPosition = float3(out.position.xy * float2(0.5, -0.5) + 0.5, 1.0);
    out.texcoord = out.position.xy * 0.5 + 0.5;
    return out;
}

float circlesFunc(const float2 uv, const float2 origin, const float time, const float size)
{
    float circle = time - length(uv.xy - origin.xy);
    float concentricity = smoothstep(0.5, 0.6, sin(circle * size))
        * smoothstep(1.0, 0.1, circle) // fade out
        * smoothstep(0, 0.1, circle); // fade in
    return concentricity;
}

half3 rippleFunc(const float2 uv, const float rippleTime, const float freq, const float timeToDie)
{
    //fmod to make it go from 0-1 in timeToDie seconds
    float t = fmod(rippleTime / timeToDie, 1.0);
    float r = 2.0 * 2.0 * t;
    float len = dot(uv, uv);
    if (len > r)
    {
        return half3(0.0);
    }
    float phi = (len - r) * freq; //phase
    half3 result = half3(cos(phi) * freq * uv.x * 2.0, cos(phi) * freq * uv.y * 2.0, sin(phi));
    
    half3 ratio = -half3(uv.x * 2.0, uv.y * 2.0, len - r) / r;
    ratio = half3(ratio.xy * ratio.z + ratio.xy * ratio.z, ratio.z * ratio.z);
    result = half3(result.xy * ratio.z + ratio.xy * result.z, result.z * ratio.z) * (1.0 - t);
    
    return result * 0.5;
}

fragment half4 rippleFragment(RasterizerData stageIn [[stage_in]],
                              texture2d<half> backgroundTexture [[texture(0)]],
                              sampler samp [[sampler(0)]],
                              constant float2& resolution[[buffer(0)]],
                              constant float& count[[buffer(1)]],
                              constant RippleData* rippleData[[buffer(2)]],
                              constant float& timeToDie[[buffer(3)]])
{
    float2 uv = stageIn.texcoord;
    const float attenuation = 0.04;
    
#ifdef FANCY
    const float frequency = 16;
    half3 ripple = 0.0h;
    for(int i = 0; i < count; ++i)
    {
        ripple = mix(rippleFunc((uv - rippleData[i].origin) * 5, rippleData[i].time, frequency, timeToDie), ripple, half3(0.5));
    }
    return backgroundTexture.sample(samp, stageIn.texcoord + float2(ripple.xy * attenuation));
#else
    float concentric = 0;
    for(int i = 0; i < count; ++i)
    {
        concentric += circlesFunc(uv, rippleData[i].origin, rippleData[i].time, 25);
    }
    return backgroundTexture.sample(samp, stageIn.texcoord + concentric * attenuation);
#endif
    
}
