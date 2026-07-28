serve place="elementium":
    cd modules/{{place}} && rojo serve

build place="elementium":
    cd modules/{{place}} && rojo build -o {{place}}.rbxl