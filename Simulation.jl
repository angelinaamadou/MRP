include("./map_snippet.jl")
using DataFrames
using StatsBase
using Query
using DataFrames, CSV
using Gadfly
using HDF5
using JLD
using StatsBase



set_default_plot_size(16cm, 14cm)

nodes_edges = load("nodes_edges.jld")["nodes"]
nodes_pop =  load("nodes_pop.jld")["nodes"]




md = loadMapData("map.osm");
r = :none



## Get network from map
nodes = OpenStreetMap.ENU(md.osmData[1], center(md.bounds))
highways = md.osmData[2]
roads = roadways(highways)
bounds = OpenStreetMap.ENU(md.bounds, center(md.bounds))
intersections = findClassIntersections(highways, roads)

##  Filter out pedestrian roads, such as parking lot entrances and driveways
## classes 1-6 represent roads used for typical routing (levels 7 and 8 are service and pedestrian roads, such as parking, lot entrances and driveways)

network = createGraph(segmentHighways(nodes, highways,  intersections, roads,Set(1:6)),intersections)


######################### Simulation ############################
mutable struct TravelPath
    startingDA::Int64
    destinationDA::Int64
end

###  Take time to perform the experiment ####
tic();

sim_stats=Dict()

num_iterations =1000000
iter=1
while(iter <= num_iterations)

    ### Select  attribute ECYBASLF
    # get sample of centroids weighted by labour population
    start_node = sample(collect(skipmissing(nodes_pop[:node])), Weights(collect(skipmissing(nodes_pop[:ECYBASLF]))),1)
    start_node = start_node[1]

    ## Filter work data that belong to the sampled node
    dg=nodes_edges[nodes_edges[:DA_I_nodes] .== start_node,:]

    ## get destination node for sampled node
    end_node= sample(collect(skipmissing(dg[:DA_J_nodes])), Weights(collect(skipmissing(dg[:Prob]))),1)
    end_node = end_node[1]

    ### Get travel paths
    tp = TravelPath(start_node,end_node)

    if start_node == end_node
        continue
    else
        try
            ## Get shortest path between the two nodes
            shortest_route, shortest_distance, shortest_time = shortestRoute(network, tp.startingDA, tp.destinationDA)
            list_nodes = shortest_route
            for node_id in list_nodes
                node_stats = Dict()
                # check to see if node already created if not create a new one
                if haskey(sim_stats, node_id)
                    node_stats = sim_stats[node_id]
                end
                if  haskey(node_stats, tp.startingDA)
                    node_stats[tp.startingDA] += 1
                else
                    node_stats[tp.startingDA] = 1
                end
                sim_stats[node_id] = node_stats
            end
        catch e
            if isa(e, LoadError)
                println("Error Empty")
            ifelse isa(e, ArgumentError)
                println("Error Argument")
            end
        end
    end
    println("iter", iter)
    iter+=1

end

save("sim_stats1000000.jld", "data", sim_stats) ;
toc();

