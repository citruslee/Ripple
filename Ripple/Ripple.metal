//
//  Ripple.metal
//  Ripple
//
//  Created by Laszlo Nagy on 14/03/2021.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float3 normalizedPosition;
    float2 texcoord;
} RasterizerData;


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

float genCircles(float2 uv, float2 origin, float time, float size)
{
    float circle = time - length(uv.xy - origin.xy);
    float concentric = smoothstep(0.5, 0.6, sin(circle * size)) //concentricity
        * smoothstep(1.0, 0.1, circle) // fade out
        * smoothstep(0, 0.1, circle); // fade in
    return concentric;
}

typedef struct {
    float time;
    float2 origin;
} RippleData;

fragment half4 rippleFragment(RasterizerData stageIn [[stage_in]],
                              texture2d<half> backgroundTexture [[texture(0)]],
                              sampler samp [[sampler(0)]],
                              constant float2& resolution[[buffer(0)]],
                              constant float& count[[buffer(1)]],
                              constant RippleData* ripples[[buffer(2)]])
{
    float2 uv = stageIn.texcoord;
    float2 texelSize = 1 / resolution;
    
    float concentric = 0;
    for(int i = 0; i < count; ++i)
    {
        concentric += genCircles(uv, ripples[i].origin, ripples[i].time, 25);
    }
    
    //return half4(concentric, concentric, concentric, 1.0);
    return backgroundTexture.sample(samp, stageIn.texcoord + float2(concentric * 0.04, concentric * 0.04));
}
