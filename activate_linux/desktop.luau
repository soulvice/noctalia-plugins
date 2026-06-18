

local image_file = desktopWidget.getConfig("image_name")
local distro_name = desktopWidget.getConfig("distro")
local show_image = desktopWidget.getConfig("show_image")

local function render()
    local rows = {

        ui.label({
            text = "Activate Linux",
            fontSize = 42,
            fontWeight = "bold",
            color = "primary",

        }),
        ui.label({
            text = "Got to Settings to activate linux.",
            fontSize = 38,
            color = "primary",
        })
    }

    local content = {}

    if show_image and image_file then
        table.insert(content, ui.image({
            path = image_file,
            height = 150,
            width = 150
        }))
    end

    table.insert(content, ui.column({ gap = 2, align = "start" }, rows ))

    desktopWidget.render(ui.row({ padding = 5, flexGrow = false  }, content))
end


function update()
    desktopWidget.setWantsSecondTicks(true)
    render()
end
