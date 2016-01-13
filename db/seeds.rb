mesharray = [ 5.0, 10.0, 25.0, 50.0 ]

Beam.create!(name: "Units Test",
             length: 1000.0,
             width: 3.93701,
             height: 0.164042,
             material: "Steel",
             modulus: 200000.0,
             poisson: 0.29,
             density: 0.28,
             meshsize: 1.0,
             load: 203.9432,
             length_unit: "mm",
             width_unit: "in",
             height_unit: "ft",
             modulus_unit: "mpa",
             density_unit: "lbin3",
             meshsize_unit: "cm",
             load_unit: "kgf",
             result_unit_system: "imperial_ksi")

Beam.create!(name: "Long Beam",
             length: 1.0,
             width: 5.0,
             height: 5.0,
             material: "Steel",
             modulus: 200.0,
             poisson: 0.29,
             density: 7600,
             meshsize: 0.5,
             load: 0.0,
             length_unit: "m",
             width_unit: "mm",
             height_unit: "mm",
             modulus_unit: "gpa",
             density_unit: "kgm3",
             meshsize_unit: "mm",
             load_unit: "n",
             result_unit_system: "metric_mpa")

Beam.create!(name: "Stubby Beam",
             length: 30.0,
             width: 30.0,
             height: 30.0,
             material: "Steel",
             modulus: 200.0,
             poisson: 0.29,
             density: 7600,
             meshsize: 1.0,
             load: 1000.0,
             length_unit: "mm",
             width_unit: "mm",
             height_unit: "mm",
             modulus_unit: "gpa",
             density_unit: "kgm3",
             meshsize_unit: "mm",
             load_unit: "n",
             result_unit_system: "metric_mpa")

mesharray.each do |n|
  name = "Steel Beam #{n}mm"
  meshsize = n.to_f / 1000
  Beam.create!(name: name,
               length: 1.0,
               width:  0.1,
               height: 0.05,
               material: "Steel",
               modulus: 200.0,
               poisson: 0.29,
               density: 7600,
               meshsize: meshsize,
               load: 2000)
end

mesharray.each do |n|
  name = "Aluminum Beam #{n}mm"
  meshsize = n.to_f / 1000
  Beam.create!(name: name,
               length: 1.0,
               width:  0.1,
               height: 0.05,
               material: "Aluminum",
               modulus: 69.0,
               poisson: 0.33,
               density: 2700,
               meshsize: meshsize,
               load: 2000)
end

mesharray.each do |n|
  name = "Grey Cast Iron 25 Beam #{n}mm"
  meshsize = n.to_f / 1000
  Beam.create!(name: name,
               length: 1.0,
               width:  0.1,
               height: 0.05,
               material: "ASTM 25 Gray Cast Iron",
               modulus: 90.5,
               poisson: 0.29,
               density: 7150,
               meshsize: meshsize,
               load: 2000)
end

mesharray.each do |n|
  name = "Grey Cast Iron 60 Beam #{n}mm"
  meshsize = n.to_f / 1000
  Beam.create!(name: name,
               length: 1.0,
               width:  0.1,
               height: 0.05,
               material: "ASTM 60 Gray Cast Iron",
               modulus: 151.5,
               poisson: 0.29,
               density: 7150,
               meshsize: meshsize,
               load: 2000)
end

99.times do |n|
  name = "Example Beam #{n}"
  Beam.create!(name: name,
               length: 1.0,
               width:  0.1,
               height: 0.05,
               material: "Steel",
               modulus: 151.5,
               poisson: 0.29,
               density: 7150,
               meshsize: 0.01,
               load: 2000)
end
