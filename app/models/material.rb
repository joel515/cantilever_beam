class Material < ActiveRecord::Base
  has_many :beams
  validates :name,    presence: true
  validates :modulus, presence: true, numericality: { greater_than: 0 }
  validates :poisson, presence: true,
                      numericality: { greater_than_or_equal_to: -1,
                                      less_than_or_equal_to: 0.5 }
  validates :density, presence: true,
                      numericality: { greater_than_or_equal_to: 0 }
  validates :modulus_unit, presence: true
  validates :density_unit, presence: true

  validates_inclusion_of :modulus_unit,  in: STRESS_UNITS.keys.map(&:to_s)
  validates_inclusion_of :density_unit,  in: DENSITY_UNITS.keys.map(&:to_s)
end
