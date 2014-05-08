require 'open-uri'

class PagesController < ApplicationController
  def index
    Casedata.delete_all
    alldata = JSON.load(open("http://data.sfgov.org/resource/vw6y-z8j6.json"))
    for item in alldata
      if (item != {})
        new_record = Casedata.new
        new_record.category = item['category']
        new_record.status = item['status']
        new_record.opened = Time.parse(item['opened']).to_i
        if (item['point'])
          new_record.longitude = item['point']['longitude']
          new_record.latitude = item['point']['latitude']
        end
        new_record.original_json = item.to_json
        new_record.save
      end # if
    end # for
    @number_of_records = alldata.count
  end # def index

  def cases
    filters = []
    if (params.has_key?(:since))
      filters.push "opened > #{params[:since].to_i}"
    end
    if (params.has_key?(:status))
      filters.push "status = #{Casedata.connection.quote(params[:status])}"
    end
    if (params.has_key?(:category))
      filters.push "category = #{Casedata.connection.quote(params[:category])}"
    end
    if (params.has_key?(:near))
      # here we will get all cases within a 10x10 miles square centered around the "near" point
      # below we will filter again to within a 5 mile radius as per the actual spec
      near_lat, near_lng = params[:near].split(",").map{ |a| a.to_f }
      miles_in_lat = 69.11 # 1° of latitude = 69.11 miles 
      miles_in_lng = 69.11 * Math.cos(near_lat * Math::PI / 180) # 1° of longitude = (69.11) x (cosine of the latitude) miles
      filters.push "latitude BETWEEN #{near_lat - (5/miles_in_lat)} AND #{near_lat + (5/miles_in_lat)}"
      filters.push "longitude BETWEEN #{near_lng - (5/miles_in_lng)} AND #{near_lng + (5/miles_in_lng)}"
    end

    search_query = 'select * from casedata'
    if (filters.any?)
      search_query += ' where ' + filters.join(' and ')
    end
    results = Casedata.find_by_sql(search_query)

    if (params.has_key?(:near))
      # above we eliminated cases than were more than 5 miles north, east, south, west
      # here we'll filter out points that are actually more than 5 miles away
      # rather than find the sqrt of lat^2 + lng^2, it's more efficient to square both sides of the equation
      results = results.select { |a| ((a.latitude - near_lat)*miles_in_lat) ** 2 + ((a.longitude - near_lng)*miles_in_lng) ** 2 < 25 }
    end

    render :text => "[" + results.map{ |a| a.original_json }.join(',') + "]"
  end
end
