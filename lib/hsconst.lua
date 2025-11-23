-- module
local HSC = {}

-- public consts
HSC.NOTELEN = {1 / 32, 1 / 24, 1 / 16, 1 / 12, 1 / 8, 1 / 6, 1 / 4, 1 / 3, 1 / 2, 3 / 4, 1, 2, 3, 4, 6, 8}
HSC.NOTELEN_STR = {"1/32", "1/24", "1/16", "1/12", "1/8", "1/6", "1/4", "1/3", "1/2", "3/4", "1", "2", "3", "4", "6", "8"}
HSC.W = 128
HSC.H = 64
HSC.LINEHEIGHT = 8
HSC.ARRAYNAMES = {"note", "vel", "oct", "off_a", "off_b", "gate", "slide"}
HSC.ARRDIS = {"Deg", "Vel", "Oct", "M-A", "M-B", "Gat", "Sld"}
HSC.BOUNDS = {{1, 7}, {1, 8}, {1, 8}, {-12, 12}, {-12, 12}, {0, 0}, {0, 0}}

-- public functions
function HSC.n(name)
  return "hs_ohoneoh_seq_" .. name
end

return HSC
