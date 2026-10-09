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

    float offset = 1.0;

    float left = metaball_field(pixel - vec2(offset, 0));
    float right = metaball_field(pixel + vec2(offset, 0));
    float down = metaball_field(pixel - vec2(0, offset));
    float up = metaball_field(pixel + vec2(0, offset));

    vec2 normal = normalize(vec2(left - right, down - up));

    vec2 light_dir = normalize(vec2(0.5, -0.8));

    float diffuse = max(dot(normal, light_dir), 0.0);

    vec3 base_color = vec3(0.4, 0.7, 1.0);
    vec3 color = base_color * (0.3 + diffuse * 0.7);

    float alpha = smoothstep(0.8, 1.2, field);

    FragColor = vec4(color, alpha);
}