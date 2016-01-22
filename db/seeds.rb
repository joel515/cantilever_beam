mesharray = [ 5.0, 10.0, 25.0, 50.0 ]

steel = Material.create!(name: "Structural Steel",
                         modulus: 200.0,
                         poisson: 0.3,
                         density: 7850.0,
                         modulus_unit: "gpa",
                         density_unit: "kgm3",
                         deletable: false)

aluminum = Material.create!(name: "Aluminum Alloy",
                            modulus: 71.0,
                            poisson: 0.33,
                            density: 2770.0,
                            modulus_unit: "gpa",
                            density_unit: "kgm3",
                            deletable: false)

Material.create!(name: "Concrete",
                 modulus: 30.0,
                 poisson: 0.18,
                 density: 2300.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

Material.create!(name: "Copper Alloy",
                 modulus: 110.0,
                 poisson: 0.34,
                 density: 8300.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

iron = Material.create!(name: "Gray Cast Iron",
                        modulus: 110.0,
                        poisson: 0.28,
                        density: 7200.0,
                        modulus_unit: "gpa",
                        density_unit: "kgm3",
                        deletable: false)

Material.create!(name: "Magnesium Alloy",
                 modulus: 45.0,
                 poisson: 0.35,
                 density: 1800.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

Material.create!(name: "Polyethylene",
                 modulus: 1.1,
                 poisson: 0.42,
                 density: 950.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

Material.create!(name: "Stainless Steel",
                 modulus: 193.0,
                 poisson: 0.31,
                 density: 7750.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

Material.create!(name: "Titanium Alloy",
                 modulus: 96.0,
                 poisson: 0.36,
                 density: 4620.0,
                 modulus_unit: "gpa",
                 density_unit: "kgm3",
                 deletable: false)

steel.beams.create!(name: "Units Test",
                    length: 1000.0,
                    width: 3.93701,
                    height: 0.164042,
                    meshsize: 1.0,
                    load: 203.9432,
                    length_unit: "mm",
                    width_unit: "in",
                    height_unit: "ft",
                    meshsize_unit: "cm",
                    load_unit: "kgf",
                    result_unit_system: "imperial_ksi")

steel.beams.create!(name: "Long Beam",
                    length: 1.0,
                    width: 5.0,
                    height: 5.0,
                    meshsize: 0.5,
                    load: 0.0,
                    length_unit: "m",
                    width_unit: "mm",
                    height_unit: "mm",
                    meshsize_unit: "mm",
                    load_unit: "n",
                    result_unit_system: "metric_mpa")

steel.beams.create!(name: "Stubby Beam",
                    length: 30.0,
                    width: 30.0,
                    height: 30.0,
                    meshsize: 1.0,
                    load: 1000.0,
                    length_unit: "mm",
                    width_unit: "mm",
                    height_unit: "mm",
                    meshsize_unit: "mm",
                    load_unit: "n",
                    result_unit_system: "metric_mpa")

mesharray.each do |n|
  name = "Steel Beam #{n}mm"
  meshsize = n.to_f / 1000
  steel.beams.create!(name: name,
                      length: 1.0,
                      width:  0.1,
                      height: 0.05,
                      meshsize: meshsize,
                      load: 2000)
end

mesharray.each do |n|
  name = "Aluminum Beam #{n}mm"
  meshsize = n.to_f / 1000
  aluminum.beams.create!(name: name,
                         length: 1.0,
                         width:  0.1,
                         height: 0.05,
                         meshsize: meshsize,
                         load: 2000)
end

mesharray.each do |n|
  name = "Gray Cast Iron Beam #{n}mm"
  meshsize = n.to_f / 1000
  iron.beams.create!(name: name,
                     length: 1.0,
                     width:  0.1,
                     height: 0.05,
                     meshsize: meshsize,
                     load: 2000)
end

99.times do |n|
  name = "Example Beam #{n}"
  steel.beams.create!(name: name,
                      length: 1.0,
                      width:  0.1,
                      height: 0.05,
                      meshsize: 0.01,
                      load: 2000)
end
