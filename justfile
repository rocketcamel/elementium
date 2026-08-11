serve place="elementium":
    cd modules/{{place}} && rojo serve

sourcemap:
  rojo sourcemap -o sourcemap.json

build place="elementium":
    cd modules/{{place}} && rojo build -o {{place}}.rbxl
