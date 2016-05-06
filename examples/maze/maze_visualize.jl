include("maze.jl")

using ModernGL, GeometryTypes, GLAbstraction, GLWindow, Images, FileIO, Reactive

function rectangle(start, width, height, pos, cols, elms)
	indx = length(pos)
	
	push!(pos, start)
	push!(pos, (start[1] + width, start[2]))
	push!(pos, (start[1], start[2] - height))
	push!(pos, (start[1] + width, start[2] - height))

	push!(elms, (indx, indx+1, indx+2))
	push!(elms, (indx+1, indx+2, indx+3))
	
	for i=1:4; push!(cols, (0.0, 0.0, 0.0)); end
end

function agent_model(start, width, height, pos, cols, elms)
	indx = length(pos)
	push!(pos, (start[1] + width*0.5, start[2] - height*0.25))
	push!(pos, (start[1] + width*0.75, start[2] - height*0.75))
	push!(pos, (start[1] + width*0.25, start[2] - height*0.75))

	push!(cols, (1.0, 0.0, 0.0))
	push!(cols, (0.0, 1.0, 0.0))
	push!(cols, (0.0, 1.0, 0.0))

	push!(elms, (indx, indx+1, indx+2))
end

function key_callback(window, key, scancode, action, mode)
	if key == GLFW.KEY_ESCAPE && action == GLFW.PRESS
		GLFW.SetWindowShouldClose(window, true)
	else
		global env
		global orientation
		global signal
		global ro
		global a_ro
		hm, wm,_ = size(env.maze)
		w = 2.0 / wm
		h = 2.0 / hm

		if key == GLFW.KEY_A && action == GLFW.PRESS
			for i=1:30
				push!(signal, rotationmatrix_z(deg2rad(3)))
				Reactive.run_till_now()
				glClear(GL_COLOR_BUFFER_BIT)
				render(ro)
				render(a_ro)
				GLFW.SwapBuffers(window)
				sleep(0.001)
			end

		elseif key == GLFW.KEY_M && action == GLFW.PRESS
			for i=1:30
				push!(signal, translationmatrix(Vec((w/30.0,0.0,0.0))))
				Reactive.run_till_now()
				glClear(GL_COLOR_BUFFER_BIT)
				render(ro)
				render(a_ro)
				GLFW.SwapBuffers(window)
				sleep(0.001)
			end

		end
	end
end	

function main()
	wm = 10
	hm = 10
	global env = MazeEnv((hm,wm))
	agent = QLearner(env)

	global orientation = 1

	println("Start: $(env.start)")
	println("Goal: $(env.goal)")

	window = create_glcontext("Maze Solving", resolution=(800, 600))

	vao = glGenVertexArrays()
	glBindVertexArray(vao)

	w = 2.0 / wm
	h = 2.0 / hm

	positions = Point{2, Float32}[]
	clrs = Vec3f0[]
	elements = Face{3, UInt32, -1}[]

	a_positions = Point{2, Float32}[]
	a_clrs = Vec3f0[]
	a_elements = Face{3, UInt32, -1}[]

	
	agent_model((-1, 1), 2.0, 2.0, a_positions, a_clrs, a_elements)
	
	for i=1:wm
		for j=1:hm
			start = (-1 + (i-1)*w, 1 - (j-1)*h)
			if env.maze[j, i, 1] == 0
				rectangle(start, w, h / 10.0, positions, clrs, elements)
			end
			if env.maze[j, i, 2] == 0 && i == wm
				s = (start[1] + w * 0.9, start[2])
				rectangle(s, w / 10.0, h, positions, clrs, elements)
			end
			if env.maze[j, i, 3] == 0 && j == hm
				s = (start[1], start[2] - h * 0.9)
				rectangle(s, w, h / 10.0, positions, clrs, elements)
			end
			if env.maze[j, i, 4] == 0
				rectangle(start, w / 10.0, h, positions, clrs, elements)
			end
		end
	end
	

	vertex_source= vert"""
	# version 150
	in vec2 position;
	in vec3 color;

	uniform mat4 model;
	uniform mat4 view;
	uniform mat4 proj;

	out vec3 Color;
	void main()
	{
	Color = color;
	gl_Position = proj * view * model * vec4(position,0.0, 1.0);
	}
	"""
	fragment_source = frag"""
	# version 150
	in vec3 Color;
	out vec4 outColor;
	void main()
	{
	outColor = vec4(Color, 1.0);
	}
	"""
	
	global signal = Signal(rotate(0f0, Vec((0,0,1f0))))
	model = rotate(0f0, Vec((0,0,1f0)))
	view = rotate(0f0, Vec((0,0,1f0)))
	a_model = foldp(*, rotate(0f0, Vec((0,0,1f0))), signal)

	#view = lookat(Vec3((1.2f0, 1.2f0, 1.2f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))
	#proj = perspectiveprojection(Float32, 45, 800/600, 1, 10)
	proj = orthographicprojection(Float32, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0)
	

	bufferdict = Dict(:position=>GLBuffer(positions),
	:color=>GLBuffer(clrs),
	:indexes=>indexbuffer(elements),
	:model=>model,
	:view=>view,
	:proj=>proj,
	)		

	a_bufferdict = Dict(:position=>GLBuffer(a_positions),
	:color=>GLBuffer(a_clrs),
	:indexes=>indexbuffer(a_elements),
	:model=>a_model,
	:view=>translationmatrix(Vec((-(wm / 2 - 0.5)*w, (hm/2 + 0.5 - env.start[1])*h , 0.0))) * scalematrix(Vec((1.0/wm, 1.0/hm, 1.0f0))),
	#:view=>scalematrix(Vec((1.0/wm, 1.0/hm, 1.0f0))),
	:proj=>proj
	)		


	global ro = std_renderobject(bufferdict, LazyShader(vertex_source, fragment_source))
	global a_ro = std_renderobject(a_bufferdict, LazyShader(vertex_source, fragment_source))
	
	GLFW.SetKeyCallback(window, key_callback)

	glClearColor(1.0,1.0,1.0,1.0)

	while !GLFW.WindowShouldClose(window)
		glClear(GL_COLOR_BUFFER_BIT)
		render(ro)
		render(a_ro)
		GLFW.SwapBuffers(window)
		GLFW.PollEvents()
	end			
end

main()
