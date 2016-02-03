  SERVER = `hostname`.strip.to_sym

  case SERVER
  when :khaleesi
    WITH_PBS =  false
    SOLVERS = {
      elmer: "Elmer"
    }
    MAX_PPN = 8
    MAX_NODE = 1
  when :login
    WITH_PBS =  true
    SOLVERS = {
      elmer: "Elmer",
      ansys: "Ansys"
    }
    MAX_PPN = 16
    MAX_NODE = 16
  else
    WITH_PBS =  false
    SOLVERS = {
      elmer: "Elmer",
      ansys: "Ansys"
    }
    MAX_PPN = 1
    MAX_NODE = 1
  end

  GRAVITY = 9.80665

  DIMENSIONAL_UNITS = {
    m:  { convert: 1,      text: "m" },
    mm: { convert: 0.001,  text: "mm" },
    cm: { convert: 0.01,   text: "cm" },
    in: { convert: 0.0254, text: "in" },
    ft: { convert: 0.3048, text: "ft" }
  }
  FORCE_UNITS = {
    n:   { convert: 1,                    text: "N" },
    kn:  { convert: 1000,                 text: "kN" },
    kgf: { convert: GRAVITY,              text: "kgf" },
    lbf: { convert: 4.448221615255,       text: "lbf" },
    kip: { convert: 4448.221615255,       text: "kip" }
  }
  STRESS_UNITS = {
    pa:  { convert: 1,              text: "Pa" },
    kpa: { convert: 1e3,            text: "kPa" },
    mpa: { convert: 1e6,            text: "MPa" },
    gpa: { convert: 1e9,            text: "GPa" },
    psi: { convert: 6894.757293178, text: "psi" },
    ksi: { convert: 6894757.293178, text: "ksi" }
  }
  DENSITY_UNITS = {
    kgm3:     { convert: 1,            text: "kg/m&sup3;".html_safe },
    tonnemm3: { convert: 1e12,         text: "tonne/mm&sup3;".html_safe },
    gcm3:     { convert: 1000,         text: "gm/cm&sup3;".html_safe },
    gm3:      { convert: 0.001,        text: "gm/m&sup3;".html_safe },
    lbin3:    { convert: 27679.90471019, text: "lb/in&sup3;".html_safe },
    lbft3:    { convert: 16.01846337395, text: "lb/ft&sup3;".html_safe }
  }
  INERTIA_UNITS = {
    m4:  { convert: 1,         text: "m<sup>4</sup>".html_safe },
    mm4: { convert: 0.001**4,  text: "mm<sup>4</sup>".html_safe },
    in4: { convert: 0.0254**4, text: "in<sup>4</sup>".html_safe }
  }
  MASS_UNITS = {
    kg:  { convert: 1,           text: "kg" },
    lbm: { convert: 1 / 2.20462, text: "lbm" }
  }
  TORQUE_UNITS = {
    nm:   { convert: 1,                       text: "N-m" },
    nmm:  { convert: 0.001,                   text: "N-mm" },
    inlb: { convert: 4.448221615255 * 0.0254, text: "in-lbf" },
    ftlb: { convert: 4.448221615255 * 0.3048, text: "ft-lbf" }
  }
  UNIT_DESIGNATION = {
    name:     nil,
    length:   DIMENSIONAL_UNITS,
    width:    DIMENSIONAL_UNITS,
    height:   DIMENSIONAL_UNITS,
    meshsize: DIMENSIONAL_UNITS,
    modulus:  STRESS_UNITS,
    poisson:  nil,
    density:  DENSITY_UNITS,
    material: nil,
    load:     FORCE_UNITS,
    inertia:  INERTIA_UNITS,
    mass:     MASS_UNITS,
    torque:   TORQUE_UNITS
  }
  RESULT_UNITS = {
    metric_mpa:   { displ:            DIMENSIONAL_UNITS[:mm],
                    displ_fem:        DIMENSIONAL_UNITS[:mm],
                    stress:           STRESS_UNITS[:mpa],
                    stress_fem:       STRESS_UNITS[:mpa],
                    force_reaction:   FORCE_UNITS[:n],
                    inertia:          INERTIA_UNITS[:mm4],
                    mass:             MASS_UNITS[:kg],
                    moment_reaction:  TORQUE_UNITS[:nmm],
                    text:             "Metric (MPa)" },
    metric_pa:    { displ:            DIMENSIONAL_UNITS[:m],
                    displ_fem:        DIMENSIONAL_UNITS[:m],
                    stress:           STRESS_UNITS[:pa],
                    stress_fem:       STRESS_UNITS[:pa],
                    force_reaction:   FORCE_UNITS[:n],
                    inertia:          INERTIA_UNITS[:m4],
                    mass:             MASS_UNITS[:kg],
                    moment_reaction:  TORQUE_UNITS[:nm],
                    text:             "Metric (Pa)" },
    imperial_psi: { displ:            DIMENSIONAL_UNITS[:in],
                    displ_fem:        DIMENSIONAL_UNITS[:in],
                    stress:           STRESS_UNITS[:psi],
                    stress_fem:       STRESS_UNITS[:psi],
                    force_reaction:   FORCE_UNITS[:lbf],
                    inertia:          INERTIA_UNITS[:in4],
                    mass:             MASS_UNITS[:lbm],
                    moment_reaction:  TORQUE_UNITS[:inlb],
                    text:             "Imperial (psi)" },
    imperial_ksi: { displ:            DIMENSIONAL_UNITS[:in],
                    displ_fem:        DIMENSIONAL_UNITS[:in],
                    stress:           STRESS_UNITS[:ksi],
                    stress_fem:       STRESS_UNITS[:ksi],
                    force_reaction:   FORCE_UNITS[:kip],
                    inertia:          INERTIA_UNITS[:in4],
                    mass:             MASS_UNITS[:lbm],
                    moment_reaction:  TORQUE_UNITS[:ftlb],
                    text:             "Imperial (ksi)" }
  }
