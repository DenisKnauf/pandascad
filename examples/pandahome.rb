#!/usr/bin/env ruby

load 'openscad.rb'

s = OpenSCAD.new

def r code
	OpenSCAD::Code.new code
end

s.module :roundedBox, 'size[3]', :radius, :sidesonly do
	s.rot = s[ [0,0,0], [90,0,90], [90,90,0] ]
	s-:rot
	s.if s.sidesonly do
		s.cube s.size - s[s.radius*2,0,0], true
		s.cube s.size - s[0,s.radius*2,0], true
		s.for x: s[s.radius-s.size[0], -s.radius+s.size[0]] / 2,
				y: s[s.radius-s.size[1], -s.radius+s.size[1]] / 2 do
			s.translate( s[s.x,s.y,0]) { s.cylinder s: s.radius, h: s.size[2], center: true }
		end
	end
	s.else do
		s.cube s.size-s[0,s.radius,s.radius]*2, center: true
		s.cube s.size-s[s.radius,0,s.radius]*2, center: true
		s.cube s.size-s[s.radius,s.radius,0]*2, center: true
	end
	s.for axis: 0..2 do
		s.for x: s.radius*s[1,-1] + s.size[s.axis] / 2 * s[-1,1],
				y: s.radius*s[1,-1] + s.size[(s.axis+1)%3] / 2 *s[-1,1] do
			s.rotate( (s+:rot)[s.axis]) do
				s.translate s[s.x,s.y,0] do
					s.cylinder h: s.size[(s.axis+2)%3]-s.radius*2, r: s.radius, center: true
				end
			end
		end
	end
	s.for x: (s.radius*s[1,-1] + s.size[0]*s[-1,1]) / 2,
			y: (s.radius*s[1,-1] + s.size[1]*s[-1,1]) / 2,
			z: (s.radius*s[1,-1] + s.size[2]*s[-1,1]) / 2 do
		s.translate(s[s.x,s.y,s.z]) { s.sphere s.radius }
	end
end

s.body = s[ 114.3, 101.6, 40 ]
s.gap = 0.2
s.thick = 1
s.body_inner = s.body+s.gap
s.body_outer = s.body_inner+s.thick

s.difference do
	s.roundedBox s.body_outer, 2, true
	s.translate( s[1,1,1] * s.thick) { s.roundedBox s.body_inner, 2, true }
	s.translate( s[0,0,24]) { s.cube s[150,120,10], true }
end
