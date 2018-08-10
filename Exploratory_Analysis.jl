include("./OpenMap_v1.2/map_snippet.jl")
using DataFrames
using StatsBase
using Query
using DataFrames, CSV
using Gadfly
using HDF5
using JLD


### Exploratory Analysis using Julia DataFrame.
set_default_plot_size(14cm, 10cm)
## Get Data from OpenstreetMap and centroids from shapefile
nodes = load("data.jld")["data"]
centroids = load("centers.jld")["centers"]

## Map each centroid to an OpenstreetMap node
centroid_nodes = Dict([centroids[k]=>nodes[k] for k in keys(nodes)])

# Make a DataFrame for Processing
cn_df = DataFrame(Any[collect(keys(centroid_nodes)), collect(values(centroid_nodes))])
rename!(cn_df, :x1 => :PRCDDA,:x2 => :node)
cn_df[:PRCDDA]

###################### Demographic dataset #####################

demos=readtable("./data/demostat_data.csv")
describe(demos)

## Descriptive Statistics
ECYBASPOP_total = sum(demos[:ECYBASPOP])
ECYBASHPOP_total = sum(demos[:ECYBASHPOP])
ECYBASLF_total = sum(demos[:ECYBASLF])


ECYBASPOP_std = std(demos[:ECYBASPOP])
ECYBASHPOP_std = std(demos[:ECYBASHPOP])
ECYBASLF_std = std(demos[:ECYBASLF])


## Create new column for DA numbers
sort!(demos,:PRCDDA)
demos[:DA] = [x for x in 1:nrow(demos)]
stack_demos = stack(demos, [:ECYBASPOP,:ECYBASHPOP, :ECYBASLF], :PRCDDA)

## filter  dataframe to drop main outliers
stack_demos = stack_demos[(stack_demos[:value] .<= 5000),:] 


## Make boxplot for the population count
p = plot(stack_demos, x="variable", y="value", Geom.boxplot(method=:tukey, suppress_outliers=false),color=:variable, 
Guide.title("Winnipeg Population size per DA"),
Guide.xlabel("Variable"),
Guide.ylabel("Population size per DA"),
Theme(grid_color_focused = colorant"white", key_position = :none,
        boxplot_spacing = 20px,middle_width = 2px, point_size = 2px))

draw(PNG("Winnipeg_population.png", 6inch, 6inch), p)


## Join demosgraphic data to ccentroid shapefile data

demos[:DA] = [string("DA$x") for x in demos[:DA]]
demos[:PRCDDA] = [string(x) for x in demos[:PRCDDA]]

demos_centroids = join(demos, cn_df, on = :PRCDDA)
save("nodes_pop.jld", "nodes", demos_centroids)


### Create Barplot of Demography per DA
sort!(demos_centroids,:ECYBASPOP,rev = true)
fig1a  = plot(head(demos_centroids, 10), x=:DA, y=:ECYBASPOP, Geom.bar, 
    Guide.xlabel("DA Number"),Guide.ylabel("Number of Agents (ECYBASPOP)"),Theme(bar_spacing=1mm))

sort!(demos_centroids,:ECYBASHPOP,rev = true)
fig1b  = plot(head(demos_centroids, 10), x=:DA, y=:ECYBASHPOP, Geom.bar,
    Guide.xlabel("DA Number"),Guide.ylabel("Number of Agents (ECYBASHPOP)"),Theme(bar_spacing=1mm))

sort!(demos_centroids,:ECYBASLF,rev = true)
fig1c = plot(head(demos_centroids, 10), x=:DA, y=:ECYBASLF, Geom.bar,
    Guide.xlabel("DA Number"),Guide.ylabel("Number of Agents (ECYBASLF)"), Theme(bar_spacing=1mm))  

set_default_plot_size(30cm, 15cm)
fig1 = hstack(fig1a, fig1b,fig1c)
draw(PNG("Ten Most Populated DA", 10inch, 6inch), fig1)


################Probablity Table #########################
probabilities = readtable("./data/Winnipeg_Pij_2018.csv")
describe(probabilities)

## Drop rows with unknwon centroids
probabilities = probabilities[(probabilities[:DA_I].!="Other").&(probabilities[:DA_J].!="Other"),:]
head(probabilities)

## Create Mapping for start travel DA and end travel DA
df1 = DataFrame(DA_I =demos[:PRCDDA], Start_DA =  demos[:DA])
probabilities = join(probabilities, df1, on = :DA_I)


df2 = DataFrame(DA_J =demos[:PRCDDA], End_DA =  demos[:DA])
probabilities = join(probabilities, df2, on = :DA_J)

## Descriptive Statistics
describe(probabilities)
sum(probabilities[:Sum_Value])


## count number of intersection for each DAs
number_rows_per_centroid = by(probabilities, :Start_DA, fun-> nrow(fun))
rename!(number_rows_per_centroid , :x1 => :Number_DAs)
sort!(number_rows_per_centroid,:Number_DAs,rev = true)
p2= plot(head(number_rows_per_centroid, 10), x=:Start_DA, y=:Number_DAs, 
    #Guide.title("Number of Intersection per DA"),
    Guide.xlabel("DA Number"),
    Guide.ylabel("Number of DAs"),Geom.bar,Theme(bar_spacing=1mm))
draw(PNG("Number of Intersection per DA", 4inch, 5inch), p2)

### Grouped DAs by population and get probability
total = by(probabilities, :DA_I, dfadd-> sum(dfadd[:Sum_Value]))
rename!(total, :x1 => :Total)

describe(total[:Total])
std(total[:Total])

### Sort probablities by the total number of travel citizens

sort!(total,:Total,rev = true)
top10_DA_I = total[1:10,:]
top_10_probabilities = join(probabilities, top10_DA_I, on = :DA_I)

probabilities = join(probabilities, total, on = :DA_I)

probabilities1 = probabilities
probabilities1= probabilities1[(probabilities1[:Total] .<= 2000),:] 
p3 = plot(probabilities1 ,x =:Total,Geom.histogram,Guide.ylabel("Count"))
draw(PNG("Count of total", 7inch, 6inch), p3)

probabilities[:Prob] = probabilities[:Sum_Value] ./ probabilities[:Total]

## create weighted  graph with list of edges and map them to OpenstreetMap Data
edge_list =  probabilities[:, filter(x -> (x in [:DA_I,:DA_J, :Prob]), names(probabilities))]

## Get corresponding keys for each column in dataframe
DA_J_nodes = [centroid_nodes[i]  for i in edge_list[:DA_J] if i in keys(centroid_nodes)]
DA_I_nodes = []
DA_J_nodes = []
for i in edge_list[:DA_I]
    if  i in keys(centroid_nodes)
        push!(DA_I_nodes, centroid_nodes[i])
    else
        push!(DA_I_nodes, "NA")
    end
end
            
edge_list[:DA_I_nodes] = DA_I_nodes

for i in edge_list[:DA_J]
    if  i in keys(centroid_nodes)
        push!(DA_J_nodes, centroid_nodes[i])
    else
        push!(DA_J_nodes, "NA")
    end
end
            
edge_list[:DA_J_nodes] = DA_J_nodes

edge_list

## Drop rows with NA nodes
nodes_edges = edge_list[(edge_list[:DA_I_nodes].!="NA").&(edge_list[:DA_J_nodes].!="NA"),:]
save("nodes_edges.jld", "nodes", nodes_edges)

#################### Kalibrate Traffic Metrix Dataset ####################

traffic = readtable("./data/SAMPLE_WinnipegCMA_TRAFCAN2017Q1.csv")
describe(traffic)

## Descrptive Statistics 
std(traffic[:TRAFFIC1])
nrow(traffic)

traffic_df = traffic[:, filter(x -> (x in [:TRAFFIC1,:LONGITUDE, :LATITUDE]), names(traffic))]
traffic_df

p4 = plot(traffic_df ,x =:TRAFFIC1,Geom.histogram,Guide.ylabel("Count"))
draw(PNG("Count of total Traffic", 7inch, 6inch), p4)
