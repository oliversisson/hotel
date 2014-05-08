class CreateCasedata < ActiveRecord::Migration
  def change
    create_table :casedata do |t|
      t.string :category
      t.string :status
      t.datetime :updated
      t.integer :opened
      t.float :longitude
      t.float :latitude
      t.string :original_json

      t.timestamps
    end
  end
end
