
struct Input
{
    float2  uv_MainTex;
    float2  uv_BumpMap;
    float4  color;
    float4  data;
    float   id;
    float4  pos;
    float4 screenPos;
    float3 worldRefl;
    INTERNAL_DATA
    float3 viewDir;
};

#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
StructuredBuffer<MeshPropertiesExtended> _Properties;
#endif

fixed4 _Color;
sampler2D _MainTex;
float2 _Tiles;
float2 _TilesFur;
half _Glossiness;
half _Metallic;

samplerCUBE _Cube;
half _EnviroBlur;
float _GlobalEmission;
float _AlbedoEmission;

uniform float _FurLength;
uniform float _Cutoff;
uniform float _CutoffEnd;
uniform float _EdgeFade;
uniform float _SmoothThick;

uniform fixed3 _Gravity;
uniform float _GravityStrength;
uniform sampler2D _GravityTex;
uniform float4 _GravityTex_ST;
uniform float _GravityTexStrength;
uniform float _VelStrength;

/** When redefining the unity_ObjectToWorld Matrix, its inverse is not redefine, which produce an error in the lighting
https://forum.unity.com/threads/trying-to-rotate-instances-with-drawmeshinstancedindirect-shader-but-the-normals-get-messed-up.707600/
*/
float4x4 inverse(float4x4 input)
{
    #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
    float4x4 cofactors = float4x4(
        minor(_22_23_24, _32_33_34, _42_43_44),
        -minor(_21_23_24, _31_33_34, _41_43_44),
        minor(_21_22_24, _31_32_34, _41_42_44),
        -minor(_21_22_23, _31_32_33, _41_42_43),
        -minor(_12_13_14, _32_33_34, _42_43_44),
        minor(_11_13_14, _31_33_34, _41_43_44),
        -minor(_11_12_14, _31_32_34, _41_42_44),
        minor(_11_12_13, _31_32_33, _41_42_43),
        minor(_12_13_14, _22_23_24, _42_43_44),
        -minor(_11_13_14, _21_23_24, _41_43_44),
        minor(_11_12_14, _21_22_24, _41_42_44),
        -minor(_11_12_13, _21_22_23, _41_42_43),
        -minor(_12_13_14, _22_23_24, _32_33_34),
        minor(_11_13_14, _21_23_24, _31_33_34),
        -minor(_11_12_14, _21_22_24, _31_32_34),
        minor(_11_12_13, _21_22_23, _31_32_33)
        );
    #undef minor
    return transpose(cofactors) / determinant(input);
}

void setup(){
    #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
    MeshPropertiesExtended props = _Properties[unity_InstanceID];
    unity_ObjectToWorld = mul(props.trmat, mul(props.rotmat, props.scmat));
    unity_WorldToObject = inverse(unity_ObjectToWorld);
    #endif
}


void vertex(inout appdata_full v, out Input o){
    UNITY_INITIALIZE_OUTPUT(Input, o);

    float3 vel = float3(0, 0, 0);
    #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
    MeshPropertiesExtended props = _Properties[unity_InstanceID];
    o.id    = float(unity_InstanceID);
    o.color = props.color;
    o.data  = props.data;
    o.pos  = props.opos;

    vel     = float3(_Properties[unity_InstanceID].oscmat[0][3], 
                    _Properties[unity_InstanceID].oscmat[1][3], 
                    _Properties[unity_InstanceID].oscmat[2][3]);
    #endif

     fixed3 direction        = lerp(v.normal, _Gravity.xyz * _GravityStrength + v.normal * (1.0 - _GravityStrength), FUR_MULTIPLIER);

    //wind
    float2 uv               = frac(TRANSFORM_TEX(v.texcoord, _GravityTex) + float2(frac(_Time.y * 0.00025), frac(_Time.y * 0.0001)));
    fixed3 noiseDirection   = tex2Dlod(_GravityTex, float4(uv, 0, 0)).xyz * 2.0 - 1.0;
    noiseDirection          *= _GravityTexStrength * (_FurLength * FUR_MULTIPLIER);
    
    vel                     *= -1.0;
    vel                     *= _FurLength * FUR_MULTIPLIER;
    vel                     *= _VelStrength;

    v.vertex.xyz            += normalize(direction + vel) * _FurLength * FUR_MULTIPLIER * v.color.a;

}

void surf(Input IN, inout SurfaceOutputStandard o){

    float2 uv   = frac(frac(IN.uv_MainTex * _Tiles) + float2(_Time.y, _Time.y + 512463.156 * IN.data.w) * 0.01);
    fixed4 rgba = tex2D(_MainTex, uv) * _Color;
    fixed4 fur  = tex2D(_MainTex, frac(IN.uv_MainTex * _TilesFur));

    o.Albedo        = rgba * IN.color.rgb * ((1.0 - FUR_MULTIPLIER) * 0.5 + 0.5);
    o.Metallic      = _Metallic;
    o.Smoothness    = _Glossiness;
    o.Emission      = texCUBElod(_Cube, float4(WorldReflectionVector(IN, o.Normal), lerp(0, 10, _EnviroBlur))).rgb * _GlobalEmission;
    o.Emission      += o.Albedo * _AlbedoEmission;

    float val   = lerp(_Cutoff, _CutoffEnd, FUR_MULTIPLIER);
    o.Alpha     = smoothstep(val - _SmoothThick * 0.5, val + _SmoothThick * 0.5, fur.a);

    float alpha =   1 - (FUR_MULTIPLIER * FUR_MULTIPLIER);
    alpha       += dot(IN.viewDir, o.Normal) - _EdgeFade;

    o.Alpha     *= alpha;
    o.Alpha     = saturate(o.Alpha);
}