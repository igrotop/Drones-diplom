# app/controllers/api/v1/zones_controller.rb

module Api
  module V1
    class ZonesController < ApplicationController
      before_action :set_zone, only: [:show, :update, :destroy]

      # GET /api/v1/zones — список по имени
      def index
        zones = Zone.ordered_by_name
        render json: { data: zones }, status: :ok
      end

      def show
        render json: { data: @zone }, status: :ok
      end

      def create
        @zone = Zone.new(zone_params)
        return unless assign_boundary_from_kml!(@zone)

        if @zone.save
          render json: { message: "Зона создана", data: @zone }, status: :created
        else
          render json: { errors: @zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        return unless assign_boundary_from_kml!(@zone)

        if @zone.update(zone_params)
          render json: { message: "Зона обновлена", data: @zone }, status: :ok
        else
          render json: { errors: @zone.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @zone.destroy
        head :no_content
      end

      private

      def set_zone
        @zone = Zone.find(params[:id])
      end

      def zone_params
        params.require(:zone).permit(:name, :description, :kml_file, boundary: [])
      end

      def assign_boundary_from_kml!(zone)
        uploaded_kml = params.dig(:zone, :kml_file)
        return true if uploaded_kml.blank?

        zone.boundary = KmlPolygonParser.call(uploaded_kml.tempfile)
        true
      rescue KmlPolygonParser::ParseError => e
        render json: { errors: ["Ошибка KML: #{e.message}"] }, status: :unprocessable_entity
        false
      end
    end
  end
end
