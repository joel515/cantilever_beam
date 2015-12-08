class Beam < ActiveRecord::Base
  validates :name,     presence: true, uniqueness: { case_sensitive: false }
  validates :length,   presence: true, numericality: { greater_than: 0 }
  validates :width,    presence: true, numericality: { greater_than: 0 }
  validates :height,   presence: true, numericality: { greater_than: 0 }
  validates :meshsize, presence: true, numericality: { greater_than: 0 }
  validates :modulus,  presence: true, numericality: { greater_than: 0 }
  validates :poisson,  presence: true,
                       numericality: { greater_than_or_equal_to: -1,
                                       less_than_or_equal_to: 0.5 }
  validates :density,  presence: true, numericality: { greater_than: 0 }
  validates :material, presence: true
  validates :load,     presence: true,
                       numericality: { greater_than_or_equal_to: 0 }
end
