#version 330 core

out vec4 FragColor;

const int count = 300;

uniform vec2 balls[count];
uniform float radii[count];

float metaball_field(vec2 pixel) {
    float field = 0.0;

    for (int i = 0; i < count; i++)
    {
        vec2 delta = pixel - balls[i];

        float d2 = dot(delta, delta) + 0.001;

        field += (radii[i] * radii[i]) / d2;
    }

    return field;
}

void main()
{
    vec2 pixel = vec2(gl_FragCoord.x, 720.0 -gl_FragCoord.y);

    float field = metaball_field(pixel);

    vec3 base_color = vec3(0.1, 0.355, 0.75);

    float alpha = smoothstep(0.9, 1.1, field);

    FragColor = vec4(base_color, alpha);
}