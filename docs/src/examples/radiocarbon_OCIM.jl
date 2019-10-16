
#---------------------------------------------------------
# # Radiocarbon with OCIM1
#---------------------------------------------------------

#md # !!! tip
#md #     This example is also available as a Jupyter notebook:
#md #     [`radiocarbon_OCIM.ipynb`](@__NBVIEWER_ROOT_URL__/examples/generated/radiocarbon_OCIM.ipynb)


#---------------------------------------------------------
# ## Setup the Radiocarbon model
#---------------------------------------------------------

# We will use the same model of the radiocarbon that is in the trcaer-transport-operator example.

# Radiocarbon, ¹⁴C, is produced by cosmic rays in the lower stratosphere and upper troposphere.
# It quickly reacts with oxygen to produce ¹⁴CO₂, which is then mixed throughout the troposphere and enters the ocean through air–sea gas exchange.
# Because the halflife of radiocarbon is only 5730 years a significant amount of decay can occur before the dissolved inorganic radiocarbon (DI¹⁴C) can mix uniformally throughout the ocean.
# As such the ¹⁴C serves as a tracer label for water that was recently in contact with the atmosphere.

# ### Tracer Equation

# Mathematically, the ¹⁴C tracer concentration, denoted $R$ (for Radiocarbon), satisfies the following tracer equation:
#
# $$\frac{\partial R}{\partial t} + \nabla \cdot \left[ \boldsymbol{u} - \mathbf{K} \cdot \nabla \right] R = \Lambda(R_\mathsf{atm} - R) - R / \tau,$$
#
# where $\Lambda(R_\mathsf{atm} - R)$ represents the air–sea exchanges and $R / \tau$ the radioactive decay rate.
# ($\tau$ is the radioactive decay timescale.)

# The discretized tracer is thus given by
#
# $$\frac{\partial \boldsymbol{R}}{\partial t} + \mathbf{T} \, \boldsymbol{R} = \mathbf{\Lambda}(R_\mathsf{atm} - \boldsymbol{R}) - \boldsymbol{R} / \tau.$$


# ### Translation to AIBECS Code



# We will perform an idealized radiocarbon simulation in our model and use the ocean circulation defined earlier using AIBECS.
# In this model we prescribe the atmospheric concentration, $R_\mathsf{atm}$, to be simply equal to 1.
# (We do not specify its unit or its specific value because it is not important for determining the age of a water parcel — only the decay rate does.)

# To use AIBECS, one must put the equations into the generic form of
#
# $$\frac{\partial \boldsymbol{x}}{\partial t} + \mathbf{T}(\boldsymbol{p}) \, \boldsymbol{x} = \boldsymbol{G}(\boldsymbol{x}, \boldsymbol{p}),$$
#
# where $\boldsymbol{x}$ is the state vector, $\boldsymbol{p}$ is the vector of model parameters, $\mathbf{T}(\boldsymbol{p})$ is the transport operator, and $\boldsymbol{G}(\boldsymbol{x}, \boldsymbol{p})$ is the local sources minus sinks.

# In our radiocarbon-model context, with $\boldsymbol{x} = \boldsymbol{R}$, we have that
#
# $$\boldsymbol{G}(\boldsymbol{x}, \boldsymbol{p}) = \mathbf{\Lambda}(R_\mathsf{atm} - \boldsymbol{x}) - \boldsymbol{x} / \tau.$$
#
# Hence, we must create `T(p)` and `G(x,p)` to give AIBECS the means to simulate the tracer distribution and/or its evolution in time.

# Like for any models using AIBECS, we start by telling Julia just that:

using AIBECS

# We then load the OCIM1 model (the grid and the transport) via

wet3D, grd, T = OCIM1.load() ;

# #### Sources and Sinks

# The local sources and sinks are thus simply given by

function G(x, p)
    τ, Ratm = p.τ, p.Ratm
    return Λ(Ratm .- x, p) - x / τ
end

# where `τ` is the decay rate timescale and `Ratm` is the atmospheric concentration of radiocarbon.

# We must define the air–sea exchange rate, `Λ(x,p)`, which requires us to define which boxes are located at the surface first.
# This is done, e.g., via

iwet = findall(vec(wet3D))
surface_boxes = grd.depth_3D[iwet] .== grd.depth[1]

# The air–sea exchange rate is then given by

function Λ(x, p)
    λ, h = p.λ, p.h
    return λ / h * surface_boxes .* x
end

# where `λ` is the piston velocity and `h` is the height of the top layer of the model grid.


# #### Parameters

# For the air–sea gas exchange, we use a constant piston velocity $\lambda$ of 50m / 10years, which will happen in the top layer, of height given by, well, the height of the top layer.
# And for the radioactive decay we use a timescale $\tau$ of 5730/log(2) years.
# We define these as parameters using the dedicated API from the AIBECS:

t = empty_parameter_table()                   # initialize an empty table of parameters
add_parameter!(t, :τ, 5730u"yr"/log(2)) # radioactive decay e-folding timescale
add_parameter!(t, :λ, 50u"m" / 10u"yr") # piston velocity
add_parameter!(t, :h, grd.δdepth[1])    # height of top layer
add_parameter!(t, :Ratm, 1.0u"mol/m^3") # atmospheric concentration
t

# shows the parameters that you just created.

# We now generate a new object to contain all these parameters via

initialize_Parameters_type(t, "C14_OCIM_parameters") # creates the type for parameters
p = C14_OCIM_parameters()                            # creates the parameters object

# #### Generate the state function and its Jacobian

# The last step for the setup is for AIBECS to create $\boldsymbol{F}(\boldsymbol{x}, \boldsymbol{p}) = \boldsymbol{G}(\boldsymbol{x}, \boldsymbol{p}) - \mathbf{T}(\boldsymbol{p}) \, \boldsymbol{x}$, which defines the rate of change of the state, $\boldsymbol{x}$.
# This is done via

F, ∇ₓF = state_function_and_Jacobian(p -> T, G) # generates the state function (and its Jacobian!)
nb = length(iwet)
x = zeros(nb)
F(x,p)

#md # !!! note
#md #     Here, AIBECS has automatically created `∇ₓF`, i.e., $\nabla_{\boldsymbol{x}}\boldsymbol{F}(\boldsymbol{x}, \boldsymbol{p})$, which is the Jacobian of the system.
#md #     This Jacobian will be useful in the simulations below.

#nb # > **Note**
#nb # > Here, AIBECS has automatically created `∇ₓF`, i.e., $\nabla_{\boldsymbol{x}}\boldsymbol{F}(\boldsymbol{x}, \boldsymbol{p})$, which is the Jacobian of the system.
#nb # > This Jacobian will be useful in the simulations below.

# That's it!
# Your model is entirely setup and ready to be used for simulations!


#---------------------------------------------------------
# ## Run the Radiocarbon model
#---------------------------------------------------------


# ### Compute the steady-state

# Because this model, embedded in the OCIM1 circulation, is much bigger than when embedded in the 5-box shoebox model, it would take quite some computational resournces (in time) to implicitly time-step.
# Instead, we will directly solve for the steady-state.
# For that, we simply define the steady-state problem and solve it via

prob = SteadyStateProblem(F, ∇ₓF, x, p) # define the problem
R = solve(prob, CTKAlg()).u             # solve the problem

# This should take a few seconds on a laptop.
# Once the radiocarbon concentration is computed, we can convert it into the corresponding age, via

C14age = -log.(R) * p.τ * u"s" .|> u"yr"


# ### Plot the radiocarbon age

# First, we must rearrange the age from its column vector shape into the corresponding 3D field.
# We start by filling a 3D array of the same size as the grid with some `NaN`s. 
# (It serves as a blank canvas that we will "color" in with our computed age.)

C14age_3D = fill(NaN, size(grd))     # creates a 3D array of NaNs

# We use the indices of wet boxes, `iwet`, to fill in the 3D array, via

C14age_3D[iwet] .= ustrip.(C14age)   # Fills the wet grid boxes with the age values

# where we have removed the unit (for plotting).
# We then pick a layer to plot, e.g., the first layer with a depth larger than 700m.
# For that, we create `iz`, which is the index of that layer:

iz = findfirst(grd.depth .> 700u"m") # aim for a depth of ~ 700 m

# We then take a horizontal 2D slice of the 3D age at index `iz`

C14age_3D_1000m_yr = C14age_3D[:,:,iz]

# Finally, we plot the radiocarbon age using Cartopy, via:

ENV["MPLBACKEND"]="qt5agg"
using PyPlot, PyCall
clf()
ccrs = pyimport("cartopy.crs")
ax = subplot(projection=ccrs.EqualEarth(central_longitude=-155.0))
ax.coastlines()
lon_cyc = ustrip.([grd.lon; grd.lon[1] + 360u"°"]) # making it cyclic for Cartopy
age_cyc = hcat(C14age_3D_1000m_yr, C14age_3D_1000m_yr[:,1])
p = contourf(lon_cyc, ustrip.(grd.lat), age_cyc, levels=0:100:2000, transform=ccrs.PlateCarree(), zorder=-1)
colorbar(p, orientation="horizontal")
title("¹⁴C age at $(string(round(typeof(1u"m"),grd.depth[iz]))) depth using the OCIM1 circulation")
gcf() # gets the current figure to display
