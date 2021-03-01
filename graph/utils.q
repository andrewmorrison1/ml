// graph/utils.q - Utility functions for graphs
// Copyright (c) 2021 Kx Systems Inc

\d .ml

// Graphing creation utilities

// @private
// @kind function
// @category pipelineUtility
// @desc Connect the output of one node to the input to another 
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param edge {dictionary} Contains information about the edge node
// @return {dictionary} The graph with the relevant connection made between the 
//   inputs and outputs of two nodes.
i.connectGraph:{[graph;edge]
  edgeKeys:`sourceNode`sourceName`destNode`destName;
  connectEdge[graph]. edge edgeKeys
  }

// Pipeline creation utilities

// @private
// @kind function
// @category pipelineUtility
// @desc Extract the source of a specific node 
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param node {symbol} Name associated with the functional node
// @return {symbol} Source of the given node
i.getDeps:{[graph;node]
  exec distinct sourceNode from graph[`edges]where destNode=node
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Extract all dependent source nodes needed to run the node
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param node {symbol} Denoting the name to be associated with the functional 
//   node
// @return {symbol[]} All sources required for the given node  
i.getAllDeps:{[graph;node]
  depNodes:i.getDeps[graph]node; 
  $[count depNodes; 
    distinct node,raze .z.s[graph]each depNodes;
    node
    ]
  }

// @private
// @kind function
// @category pipelineUtility
// @desc  Extract all the paths needed to run the node
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param node {symbol} Denoting the name to be associated with the functional 
//   node
// @return {symbol} All paths required for the given node
i.getAllPaths:{[graph;node]
  depNodes:i.getDeps[graph]node; 
  $[count depNodes; 
    node,/:raze .z.s[graph]each depNodes;
    raze node
    ]
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Get the longest path
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param node {symbol} Denoting the name to be associated with the functional 
//   node
// @return {symbol} The longest path available
i.getLongestPath:{[graph;node]
  paths:reverse each i.getAllPaths[graph;node];
  paths first idesc count each paths
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Extract the optimal path to run the node
// @param graph {dictionary} Graph originally generated by .ml.createGraph, 
//   which has all relevant input edges connected validly
// @param node {symbol} Denoting the name to be associated with the functional 
//   node
// @return {symbol} The optimal path to run the node
i.getOptimalPath:{[graph;node]
  longestPath:i.getLongestPath[graph;node];
  distinct raze reverse each i.getAllDeps[graph]each longestPath
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Update input data information within the pipeline
// @param pipeline {dictionary} Pipeline created by .ml.createPipeline
// @param map {dictionary} Contains information needed to run the node
// @return {dictionary} Pipeline updated with input information
i.updateInputData:{[pipeline;map]
  pipeline[map`destNode;`inputs;map`destName]:map`data;
  pipeline
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Execute the first non completed node in the pipeline
// @param pipeline {dictionary} Pipeline created by .ml.createPipeline
// @return {dictionary} Pipeline with executed node marked as complete
i.execNext:{[pipeline]
  node:first 0!select from pipeline where not complete;
  -1"Executing node: ",string node`nodeId;
  inputs:node[`inputs]node`inputOrder;
  if[not count inputs;inputs:1#(::)];
  resKeys:`complete`error`outputs;
  resVals:$[graphDebug;
    .[(1b;`;)node[`function]::;inputs];
    .[(1b;`;)node[`function]::;inputs;{[err](0b;`$err;::)}]
    ];
  res:resKeys!resVals;
  if[not null res`error;-2"Error: ",string res`error];
  if[res`complete;
    res[`inputs]:(1#`)!1#(::);
    outputMap:update data:res[`outputs]sourceName from node`outputMap;
    uniqueSource:(exec distinct sourceName from outputMap)_ res`outputs;
    res[`outputs]:((1#`)!1#(::)),uniqueSource;
    pipeline:i.updateInputData/[pipeline;outputMap];
    ];
  pipeline,:update nodeId:node`nodeId from res;
  pipeline
  }

// @private
// @kind function
// @category pipelineUtility
// @desc Check if any nodes are left to be executed or if any
//   errors have occured
// @param pipeline {dictionary} Pipeline created by .ml.createPipeline
// @return {dictionary} Return 0b if all nodes have been completed or if any 
//   errors have occured. Otherwise return 1b
i.execCheck:{[pipeline]
  if[any not null exec error from pipeline;:0b];
  if[all exec complete from pipeline;:0b];
  1b
  }
