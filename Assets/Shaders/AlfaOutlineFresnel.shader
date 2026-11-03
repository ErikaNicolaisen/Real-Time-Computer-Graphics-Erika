// Alfa – Outline + Fresnel (URP, hand-written HLSL)
// Combines two shaders from Ronja's tutorials, ported to the Universal Render Pipeline:
//   1) Fresnel       – https://www.ronja-tutorials.com/post/012-fresnel/
//   2) Hull Outlines – https://www.ronja-tutorials.com/post/020-hull-outline/
// Pass "Main"    : texture + simple diffuse light from the main light + Fresnel rim glow
// Pass "Outline" : the "inverted hull" – the mesh is pushed out along its normals,
//                  only back faces are drawn, in one flat colour → a silhouette outline.

Shader "Custom/AlfaOutlineFresnel"
{
    Properties
    {
        _BaseMap ("Texture", 2D) = "white" {}

        [Header(Fresnel)]
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.3, 0.7, 1, 1)
        _FresnelExponent ("Fresnel Exponent", Range(0.5, 8)) = 3

        [Header(Outline)]
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineThickness ("Outline Thickness", Range(0, 0.05)) = 0.003
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        // All material properties in one constant buffer (keeps it SRP Batcher compatible)
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _FresnelColor;
            float  _FresnelExponent;
            float4 _OutlineColor;
            float  _OutlineThickness;
        CBUFFER_END
        ENDHLSL

        // ---------------------------------------------------------------
        // PASS 1 – textured object with Fresnel rim
        // ---------------------------------------------------------------
        Pass
        {
            Name "Main"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float3 normal  = normalize(IN.normalWS);
                float3 viewDir = normalize(GetWorldSpaceViewDir(IN.positionWS));

                // base colour from the scanned texture
                half3 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb;

                // simple Lambert diffuse from the main (directional) light + ambient
                Light mainLight = GetMainLight();
                half3 lighting  = mainLight.color * saturate(dot(normal, mainLight.direction)) + SampleSH(normal);
                half3 color     = albedo * lighting;

                // FRESNEL: 0 where the surface faces the camera, 1 at grazing angles (the silhouette)
                float fresnel = 1 - saturate(dot(normal, viewDir));
                fresnel = pow(fresnel, _FresnelExponent);      // higher exponent = thinner rim
                color  += fresnel * _FresnelColor.rgb;         // added on top, like emission

                return half4(color, 1);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------
        // PASS 2 – inverted hull outline
        // ---------------------------------------------------------------
        Pass
        {
            Name "Outline"
            Tags { "LightMode"="SRPDefaultUnlit" }
            Cull Front          // draw only the back faces of the enlarged mesh

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                // push every vertex outwards along its normal (object space)
                float3 grown = IN.positionOS.xyz + normalize(IN.normalOS) * _OutlineThickness;
                OUT.positionCS = TransformObjectToHClip(grown);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                return _OutlineColor;   // flat colour, no lighting
            }
            ENDHLSL
        }
    }
}
