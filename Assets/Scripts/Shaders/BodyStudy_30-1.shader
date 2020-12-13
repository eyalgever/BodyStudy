﻿Shader "BonjourLab/BodyStudy_30-1"
{
    Properties
    {
        [Header(Mat Properties)] 
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
		_CutOut ("CutOut", Range(0.0, 1)) = 0.0
        _BumpMap ("Bumpmap", 2D) = "bump" {}
        _Metallic ("_Metallic", 2D) = "black" {}
        _Roughness ("Roughness", 2D) = "grey" {}
		_RoughnessInc ("_RoughnessInc", Range(0.0, 1)) = 0.0
        _Cube ("Cubemap", CUBE) = "" {}
        _GlobalEmission ("GlobalEmission", Range(0,1)) = 0.5
        _EnviroBlur ("EnviroBlur", Range(0,1)) = 0.5
        _AlbedoEmission ("AlbedoEmission", Range(0,1)) = 0.5

        _AlphaTest("_AlphaTest", float) = 1
    }
    SubShader
    {
        Tags {"RenderType"="TransparentCutout" "Queue" = "AlphaTest" "LightMode"="ForwardBase"  "IgnoreProjector"="True"}
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 200
        Cull Off

        CGPROGRAM
        struct Input
        {
            float2 uv_MainTex;
            float2 uv_BumpMap;
            float4 color;
            float id;
    		float4 screenPos;
            float4 data;
            float4 pos;
            float3 worldRefl;
            INTERNAL_DATA
		};

        #include "Assets/Scripts/ComputeShaders/DataStructs.hlsl"
        #include "Assets/Scripts/Utils/noises.hlsl"
        #include "Assets/Scripts/Utils/easing.hlsl"
        #include "Assets/Scripts/Vertex/VertexPhysics.hlsl"

        // Physically based Standard lighting model, and enable shadows on all light types
         #pragma surface surf Standard fullforwardshadows addshadow alphatest:_CutOut vertex:vertex
        #pragma multi_compile_instancing
        #pragma instancing_options procedural:setup 
        #pragma target 5.0

        sampler2D _MainTex;
        sampler2D _BumpMap;
        sampler2D _Metallic;
        sampler2D _Roughness;
        samplerCUBE _Cube;

        half _EnviroBlur;
        fixed4 _Color;
        float _GlobalEmission;
        float _AlbedoEmission;
        float _AlphaTest;
        float _RoughnessInc;

          
        float luma(float3 color) {
            return dot(color, float3(0.299, 0.587, 0.114));
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float dividery   = 3.0;
            float offsety    = 1.0 / dividery;
            
            float dividerx   = 4.0;
            float offsetx    = 1.0 / dividerx;
            float normy      = IN.pos.y / 1.8;

            float uvy        = (IN.uv_MainTex.y / dividery) + floor(IN.pos.w * dividery) * offsety;
            float uvx        = (IN.uv_MainTex.x / dividerx) + floor(normy * dividerx) * offsetx;

            float2 uv       = float2(1.0 - uvx, uvy);

            // Albedo comes from a texture tinted by color
            fixed4 argb     = tex2D (_MainTex, uv);
            fixed4 arough   = tex2D (_Roughness, uv);
            fixed4 ametal   = tex2D (_Metallic, uv);
            float3 anormal  = UnpackNormal(tex2D (_BumpMap, uv));
            anormal.y       = 1.0 - anormal.y;

            // Metallic and smoothness come from slider variables
            o.Albedo        = argb.rgb * IN.color.rgb;
            o.Normal        = anormal;
            o.Metallic      = ametal.r;
            o.Smoothness    = arough.r * _RoughnessInc;
            o.Emission      = texCUBElod(_Cube, float4(WorldReflectionVector(IN, o.Normal), lerp(0, 10, _EnviroBlur))).rgb * _GlobalEmission;
            o.Emission      += o.Albedo * _AlbedoEmission;
            o.Alpha         = argb.a;

            float discardValue = smoothstep(0, _AlphaTest, IN.color.a);
            float4x4 thresholdMatrix =
            {  1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
            13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
            4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
            16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
            };
            float4x4 _RowAccess = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
            float2 pos = IN.screenPos.xy / IN.screenPos.w;
            pos *= _ScreenParams.xy; // pixel position

            clip(discardValue - thresholdMatrix[fmod(pos.x, 4)] * _RowAccess[fmod(pos.y, 4)]);
            
        }
        ENDCG
    }
    FallBack "Diffuse"
}
