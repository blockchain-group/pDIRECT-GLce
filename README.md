# Parallel DIRECT-GLce implementations
Parallel DIRECT-type algorithms for generally constrained global optimization problems

The code in this repository is based on the works in [[1]](#1)[[2]](#2) and is written in MATLAB.

## Getting started

- Download the entire folder containing all MATLAB files and add the entire folder and subfolders to the MATLAB path. 
- Next run `parallel_dDirect_GL`/`parallel_dDirect_Agressive`, which should run the pre-defined problem as defined in [[2]](#2).

## References

[1] L. Stripinis, R. Paulavičius, and J. Žilinskas, [Penalty functions and two-step selection procedure based DIRECT-type algorithm for constrained global optimization](http://link.springer.com/10.1007/s00158-018-2181-2), Struct. Multidiscip. Optim., vol. 59, no. 6, pp. 2155–2175, 2019.
<a name="1">
</a>

[2] L. Stripinis, J. Žilinskas, L. G. Casado, and R. Paulavičius, *On MATLAB experience in accelerating DIRECT-GLce algorithm for constrained global optimization through dynamic data structures and parallelization*, pp. 1–25. Submitted.
<a name="2">
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
