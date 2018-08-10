include("./OpenMap_v1.2/map_snippet.jl")
using DataFrames
using StatsBase
using Query
using DataFrames, CSV
using Gadfly
using HDF5
using JLD


set_default_plot_size(16cm, 14cm)
############# Time and Space complexity  #############################
Time_data =DataFrame(steps = [1000, 10000, 100000,1000000], 
                    time=[204.648279506,906.670216452,10087.945737867,98422.233072766],
                    space = [51.2,247.5,778.4, 1240]) 
t1 = plot(Time_data, x=:steps,y=:time, Guide.ylabel("Time (seconds)"), Geom.point, Geom.line, Scale.x_log10)
t2 = plot(Time_data, x=:steps,y=:space,Guide.ylabel("Space (MB)"), Geom.point, Geom.line, Scale.x_log10)
draw(PNG("./plots/Complexity.png", 7inch, 5inch), hstack(t1,t2))

################## Simulation Data ##############################
sim_stats = load("./simulated_data/sim_stats100000.jld")["data"]
sim_array =[]
for k in collect(keys(sim_stats))
    sort_k =sort(collect(sim_stats[k]), by=x->x[2], rev= true)
    push!(sim_array,[[k,x[1],x[2]] for x in sort_k])
end

sim_flat = collect(Iterators.flatten(sim_array))

sim_df = DataFrame(start_id =[x[1] for x in sim_flat], node_id = [x[2] for x in sim_flat],count = [x[3] for x in sim_flat])
sim_df

sort!(sim_df,:count,rev = true)

### Grouped node by count  to get the most populated intersections and select the 10 most popular
node_total = by(sim_df, :node_id, dfadd-> sum(dfadd[:count]))
rename!(node_total, :x1 => :Total)
sort!(node_total,:Total,rev = true)
top10_nodes = node_total[1:10,:]
node_total
top10_nodes[:Total]/sum(sim_df[:count])

## Upload OpenstreetMap data to match  simulation points
nodeslla = load("nodeslla.jld")["data"]

## Get longitude and latitude for top10 nodes
top10_array=[]
for k in top10_nodes[:node_id]
    lon = nodeslla[k].lon
    lat = nodeslla[k].lat
    push!(top10_array, [k,string(lon),string(lat)])
end
## Select top 10 busiest intersections
top10_df = DataFrame(node_id =[x[1] for x in top10_array], lon = [x[2] for x in top10_array],lat = [x[3] for x in top10_array])
top10 = join(top10_nodes,top10_df,on = :node_id)

## Get  weighted nodes from simulation
nodes_pop =  load("nodes_pop.jld")["nodes"]
sort!(nodes_pop,:PRCDDA)

## Create new column for DA name
#nodes_pop[:DA] = [x for x in 1:nrow(nodes_pop)]
rename!(nodes_pop, :node => :start_id)
nodes_pop


### Draw intersection with starting DA

count = 1
nums_DA =[]
for node_id in top10[:node_id]
    sim_node = sim_df[(sim_df[:node_id].==node_id),:]
    DAs_node = join(sim_node,nodes_pop,on = :start_id, kind = :inner )
    num_DA = [node_id,nrow(DAs_node)]
    proportion = DataFrame(node_id = "node$node_id",proportion = DAs_node[:count]/sum(DAs_node[:count]) )
    CSV.write("Proportion$node_id.csv",proportion)
    push!(nums_DA, num_DA)
    sort!(DAs_node,:DA)
    lon = top10[(top10[:node_id] .== node_id),:lon][1]
    lat = top10[(top10[:node_id] .== node_id),:lat][1]
   
    p1=plot(DAs_node[1:nrow(DAs_node),:], x= :DA,y =:count,Guide.ylabel("Number of Agents",orientation=:vertical),Guide.xticks(ticks=nothing), Guide.title("Figure 11.$count. Intersection ID $node_id \n Longitude:$lon,Latitude:$lat"), Geom.bar)
    sort!(DAs_node,:count, rev=true)
    if nrow(DAs_node) >=10
        p2=plot(DAs_node[1:10,:], x= :DA,y =:count,Guide.ylabel("Number of Agents",orientation=:vertical), Guide.title("Top 10 DAs at Intersection ID $node_id"), Geom.bar,Theme(bar_spacing=1mm))
    else
        p2=plot(DAs_node[1:nrow(DAs_node),:], x= :DA,y =:count,Guide.ylabel("Number of Agents",orientation=:vertical), Guide.title("Top 10 DAs at Intersection ID $node_id"), Geom.bar,Theme(bar_spacing=1mm))
    end
    ## Plot most important DAs for an intersection
    draw(PNG("./plots/myplot$node_id.png", 4inch, 5inch), vstack(p1,p2))
    count = count + 1
end


###################95% confidence interval calcualtion ###############
## Big sample size so approximate to normal distribution with a z factor of 1.96 (95% confidence intervals)
total_sample=sum(node_total[:Total])
println(total_sample)
function confidence_interval(sample)
    upperbound = sample/total_sample + 1.96/total_sample*sqrt(sample*(total_sample - sample)/total_sample)
    lowerbound = sample/total_sample - 1.96/total_sample*sqrt(sample*(total_sample - sample)/total_sample)
    return (lowerbound, upperbound)
end 

node_total[:sample_proportion] = node_total[:Total]/sum(node_total[:Total])
node_total[:lower_interval] = [confidence_interval(x)[1] for x in node_total[:Total]]
node_total[:upper_confidence] = [confidence_interval(x)[2] for x in node_total[:Total]]


############################ Data Validation ############################
traffic_data = load("trafficdata.jld")["data"]
traffic_df = DataFrame(node_id=[x for x in collect(keys(traffic_data))],traffic = [x for x in collect(values(traffic_data))])

## Create sample proprotion
traffic_df[:proportion] = traffic_df[:traffic]/sum(traffic_df[:traffic])

## Match traffic Data with openstreetmap data
merged_df = join(traffic_df, node_total, on = :node_id)
scaledTotal = merged_df[:sample_proportion]*sum(traffic_df[:traffic])
merged_df[:scaledTotal] = round(merged_df[:sample_proportion]*sum(traffic_df[:traffic]))


## Check for  visual data normality

merged_df[:node_id] = [string(x) for x in merged_df[:node_id]]
p1=plot(merged_df, x= :node_id,y =:traffic,Guide.xlabel("Intersection"),Guide.ylabel("Number of Agents",orientation=:vertical), Guide.xticks(ticks=nothing),Guide.title("Empirical Data "), Geom.bar,Theme(bar_spacing=1mm))
p2=plot(merged_df, x= :node_id,y =:scaledTotal,Guide.xlabel("Intersection"),Guide.ylabel("Number of Agents",orientation=:vertical),Guide.xticks(ticks=nothing), Guide.title("Simulation Data"), Geom.bar,Theme(bar_spacing=1mm))

draw(PNG("./plots/HistogramEmpiricalSimulation.png", 8inch, 5inch), hstack(p1,p2))



## Data is not normaly distributed.

## Compute the Wilcoxon Signed Rank Test
## degree of freedom df = 19

wilcoxon_data = merged_df[:, filter(x -> (x in [:node_id, :traffic, :scaledTotal]), names(merged_df))]
#shapiro-wilcoxon

wilcoxon_data[:difference] = wilcoxon_data[:traffic] - wilcoxon_data[:scaledTotal]
wilcoxon_data[:absolute_difference] =abs(wilcoxon_data[:traffic] - wilcoxon_data[:scaledTotal])
wilcoxon_data
sort!(wilcoxon_data,:absolute_difference)
wilcoxon_data[:rank] = [ x for x in 1: length(wilcoxon_data[:absolute_difference])]


T_minus = 0
T_plus = 0
for x in 1:length(wilcoxon_data[:rank])
    #println(wilcoxon_data[:difference][x])
    if wilcoxon_data[:difference][x]<=0
        T_minus+=wilcoxon_data[:rank][x]
    else
        T_plus+=wilcoxon_data[:rank][x]
    end
end
w_stat = min(T_minus, T_plus)


n=20
alpha= 0.05
##Two tailed test
wcrit = 52 
## w_stat > wcrit
##Under the null hypothesis, we would expect the distribution of the differences to be approximately
##symmetric around zero and the distribution of positives and negatives
##to be distributed at random among the ranks.
### We do not reject the null hypothesis


