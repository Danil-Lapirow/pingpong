require "crsfml"
require "debug"
require "math"

width = 1920
height = 1080

window = SF::RenderWindow.new(
  SF::VideoMode.new(width, height), "Arcanoid",
)
window.framerate_limit = 60

objects = [] of BaseObject

class Cut
    def initialize(@start : SF::Vector2f, @end : SF::Vector2f)
    end

    def _end
      @end
    end

    getter start

    def center
      return SF::Vector2f.new (@start.x + @end.x)/2, (@start.y + @end.y)/2
    end
end

class BaseObject
  @body : SF::Shape
  @@body_size : Float32 = 0

  def initialize(@body, start_pos)
    @body.position = start_pos
    @body.origin = SF::Vector2f.new(@@body_size/2, @@body_size/2)
  end

  def draw(window)
    window.draw @body
  end

  def try_move(objects : Array(BaseObject))
  end

  def vertexes : Array(SF::Vector2f)
    [] of SF::Vector2f
  end

  def body
    @body
  end

  def farthest_vertex
    vertexes = self.vertexes

    if vertexes.empty?
      return 0
    else
      (
        vertexes.map do |x|
          Math.sqrt (x.x - @body.position.x)**2 + (x.y - @body.position.y)**2
        end
      ).max
    end
  end

  def objects_possible_to_collide(objects)
    objects.select do |object|
      Math.sqrt(
        (object.body.position.x - @body.position.x)**2 + (object.body.position.y - body.position.y)**2
      ) < self.farthest_vertex + object.farthest_vertex
    end
  end

  def colliding?(objects : Array(BaseObject))
    my_vertexes = self.vertexes
    possible_collisions = self.objects_possible_to_collide objects

    cuts = [] of Cut

    if !my_vertexes.empty?
      possible_collisions.each do |object|
        other_vertexes = object.vertexes

        if !other_vertexes.empty?
          my_vertex = my_vertexes.last

          my_vertexes.each do |my_next_vertex|
            vertex = other_vertexes.last

            other_vertexes.each do |next_vertex|
              v1 = (next_vertex.x - vertex.x)*(my_vertex.y - vertex.y) - (next_vertex.y - vertex.y)*(my_vertex.x - vertex.x)
              v2 = (next_vertex.x - vertex.x)*(my_next_vertex.y - vertex.y) - (next_vertex.y - vertex.y)*(my_next_vertex.x - vertex.x)
              v3 = (my_next_vertex.x - my_vertex.x)*(vertex.y - my_vertex.y) - (my_next_vertex.y - my_vertex.y)*(vertex.x - my_vertex.x)
              v4 = (my_next_vertex.x - my_vertex.x)*(next_vertex.y - my_vertex.y) - (my_next_vertex.y - my_vertex.y)*(next_vertex.x - my_vertex.x)
              intersecting = (v1*v2 < 0) && (v3*v4 < 0)

              if intersecting
                cuts << Cut.new my_vertex, my_next_vertex
              end

              vertex = next_vertex
            end

            my_vertex = my_next_vertex
          end
        end
      end
    end
    
    if cuts.empty?
      return nil
    else
      first_cut = cuts.first
      second_cut = cuts.last
      first_center = first_cut.center
      second_center = second_cut.center

      needed_center = Cut.new(first_center, second_center).center
      Cut.new @body.position, needed_center
    end
  end
end

class MovingObject < BaseObject
  @direction : SF::Vector2f
  @@speed : Float32 = 0

  def self.body_size
    @@body_size
  end

  def velocity : SF::Vector2f
    SF::Vector2f.new(@direction.x * @@speed, @direction.y * @@speed)
  end

  def initialize(body, start_pos, @direction = SF::Vector2f.new(0, 0))
    super body, start_pos
  end

  def collision_callback(vector : Cut)
  end

  def try_move(objects)
    other_objects = objects.reject do |x|
      x.@body.position == @body.position
    end
    @body.position += velocity

    is_colliding = self.colliding? other_objects
    if !is_colliding.nil?
      @body.position -= velocity
      self.collision_callback is_colliding
    end

    is_colliding.nil?
  end
end

class Ball < MovingObject
  @@speed : Float32 = 3
  @@body_size : Float32 = 40

  def radius
    @@body_size/2
  end

  def vertexes
    step = Math::PI/4

    (0..7).map do |i|
      SF::Vector2f.new @body.position.x + radius * Math.cos(step*i), @body.position.y + radius * Math.sin(step*i)
    end
  end

  def collision_callback(cut : Cut)
    res_vector = SF::Vector2f.new cut._end.x - cut.start.x, cut._end.y - cut.start.y

    collision_rads = Math.acos((cut._end.x - cut.start.x) / Math.sqrt(res_vector.x**2 + res_vector.y**2))

    direction_rads = Math.acos(@direction.x / Math.sqrt(@direction.x**2 + @direction.y**2))

    res_rads = (direction_rads + collision_rads) % (2 * Math::PI)

    @direction = SF::Vector2f.new Math.cos(res_rads), Math.sin(res_rads)
  end

  def initialize(start_pos)
    body = SF::CircleShape.new(radius)
    super body, start_pos
    @direction = SF::Vector2f.new Math.cos((Math::PI/4*3).to_f32), Math.sin((Math::PI/4*3).to_f32)
  end
end

class Player < MovingObject
  @@speed : Float32 = 10
  @@body_size : Float32 = 50

  def initialize(start_pos)
    body = SF::RectangleShape.new(SF::Vector2f.new(@@body_size, @@body_size))
    super body, start_pos
  end

  def vertexes
    return [
      @body.position + SF::Vector2f.new(-@@body_size/2, -@@body_size/2),
      @body.position + SF::Vector2f.new(@@body_size/2, -@@body_size/2),
      @body.position + SF::Vector2f.new(@@body_size/2, @@body_size/2),
      @body.position + SF::Vector2f.new(-@@body_size/2, @@body_size/2),
    ]
  end

  def go_right
    @direction = SF::Vector2f.new 1, 0
  end

  def go_up
    @direction = SF::Vector2f.new 0, -1
  end

  def go_down
    @direction = SF::Vector2f.new 0, 1
  end

  def go_left
    @direction = SF::Vector2f.new -1, 0
  end

  def stop
    @direction = SF::Vector2f.new 0, 0
  end
end

player1 = Player.new SF::Vector2f.new((width/3 - Player.body_size/2).to_f32, 100.to_f32)
objects << player1
player2 = Player.new SF::Vector2f.new((width/2 - Player.body_size/2).to_f32, (height - 100).to_f32)
objects << player2
# ball = Ball.new SF::Vector2f.new((width - width/4 + Player.body_size/2).to_f32, 100.to_f32)
ball = Ball.new SF::Vector2f.new((width/2 - Ball.body_size/2).to_f32, (height/2 - Ball.body_size/2).to_f32)
objects << ball

while window.open?
  while event = window.poll_event
    if (
         event.is_a?(SF::Event::Closed) ||
         (event.is_a?(SF::Event::KeyPressed) && event.code.escape?)
       )
      window.close
    elsif event.is_a? SF::Event::KeyPressed
      case event.code
      when .a?
        player1.go_left
      when .d?
        player1.go_right
      when .up?
        player2.go_up
      when .left?
        player2.go_left
      when .down?
        player2.go_down
      when .right?
        player2.go_right
      end
    elsif event.is_a? SF::Event::KeyReleased
      case event.code
      when .a?, .d?
        player1.stop
      when .left?, .right?, .up?, .down?
        player2.stop
      end
    end
  end

  objects.map do |x|
    x.try_move objects
  end

  window.clear SF::Color::Black
  objects.map do |x|
    x.draw window
  end

  window.display
end
