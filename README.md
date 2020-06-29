# Parallel DIRECT-GLce implementations
Parallel DIRECT-type algorithms for box and generally constrained global optimization problems

The code in this repository is based on the works in [[1]](#1)[[2]](#2)[[3]](#3)[[4]](#4) and is written in MATLAB.

## Getting started

- Download the entire folder containing all MATLAB files and add the entire folder and subfolders to the MATLAB path. 
- Next run `parallel_dDirect_GL`/`parallel_dDirect_Agressive`, which should run the pre-defined problem as defined in [[2]](#2).
- Next run `parallel_dDirect_GLce`/`parallel_dDirect_Ace`, which should run the pre-defined problem as defined in [[3]](#3).

## References

[1] C. A. Baker, L. T. Watson, B. Grossman, W. H. Mason, R. T. Haftka, [Parallel global aircraft configuration design space exploration, in: A. Tentner (Ed.)](https://www.semanticscholar.org/paper/Parallel-Global-Aircraft-Configuration-Design-Space-Baker-Watson/2ca51b579b927476a21a4a751ef2ca8792f8944a), High Performance Computing Symposium 2000, Soc. for Computer Simulation Internat, 2000, pp. 54–66. <a name="1">
</a>

[2] L. Stripinis, R. Paulavičius, J. Žilinskas, [Improved scheme for selection of potentially optimal hyper-rectangles in DIRECT](https://link.springer.com/article/10.1007/s11590-017-1228-4), Optimization Letters 12 (7) (2018) 1699–1712. doi:10.1007/ s11590-017-1228-4. <a name="2">
</a>

[3] L. Stripinis, R. Paulavičius, and J. Žilinskas, [Penalty functions and two-step selection procedure based DIRECT-type algorithm for constrained global optimization](http://link.springer.com/10.1007/s00158-018-2181-2), Struct. Multidiscip. Optim., vol. 59, no. 6, pp. 2155–2175, 2019. <a name="3">
</a>

[4] L. Stripinis, J. Žilinskas, L. G. Casado, and R. Paulavičius, *On MATLAB experience in accelerating DIRECT-GLce algorithm for constrained global optimization through dynamic data structures and parallelization*, pp. 1–25. Submitted. <a name="4">
</a>

## Citing this implementation

Please use the following bibtex entry, if you consider to cite this implementation:

```
@misc{Stripinis2020pdirectglce,
  title={Parallel DIRECT-type algorithms for generally constrained global optimization problems in MATLAB},
  author={Stripinis, Linas},
  year={2020},
  publisher = {GitHub},
  journal = {GitHub repository},
  howpublished={\url{https://github.com/blockchain-group/pDIRECT-GLce}},
}
```
