#ifndef __SIMPLE_MATRIX_H
#define __SIMPLE_MATRIX_H

#include <iostream>
#include <cstdlib>

#pragma omp declare target
template <typename T> class Simple_Matrix
{
 private:
  unsigned n_rows;
  unsigned n_cols;
  T* matrix;

 public:
  Simple_Matrix(unsigned _n_rows, unsigned _n_cols, const T& _init_number);
  Simple_Matrix(const Simple_Matrix<T>& rmatrix);
  Simple_Matrix(unsigned _n_rows, unsigned _n_cols, const T* _init_array);
  virtual ~Simple_Matrix();

  unsigned get_n_rows() const;
  unsigned get_n_cols() const;
  void print() const;

  T& operator()(const unsigned& row, const unsigned& col);
  const T& operator()(const unsigned& row, const unsigned& col) const;
  Simple_Matrix<T>& operator=(const Simple_Matrix<T>& rmatrix);

  Simple_Matrix<T> operator*(const Simple_Matrix<T>& rmatrix);
};

template<typename T>
unsigned Simple_Matrix<T>::get_n_rows() const
{
  return this->n_rows;
}

template<typename T>
unsigned Simple_Matrix<T>::get_n_cols() const
{
  return this->n_cols;
}

template<typename T>
void Simple_Matrix<T>::print() const
{
  for (int i=0; i<n_rows; ++i)
  {
    for (int j=0; j<n_cols; ++j)
    {
      std::cout << matrix[i*n_cols+j] << ", ";
    }
    std::cout << std::endl;
  }
}

template<typename T>
T& Simple_Matrix<T>::operator()(const unsigned& row, const unsigned& col)
{
  return this->matrix[row*n_cols+col];
}

template<typename T>
const T& Simple_Matrix<T>::operator()(const unsigned& row, const unsigned& col) const
{
  return this->matrix[row*n_cols+col];
}

template<typename T>
Simple_Matrix<T>::Simple_Matrix(unsigned _n_rows, unsigned _n_cols, const T& _init_number)
{
  n_rows = _n_rows;
  n_cols = _n_cols;
  matrix = new T[n_rows*n_cols];
  for (unsigned i=0; i<n_rows*n_cols; ++i)
  {
    matrix[i] = _init_number;
  }
}

template<typename T>
Simple_Matrix<T>::Simple_Matrix(const Simple_Matrix<T>& rmatrix)
{
  n_rows = rmatrix.get_n_rows();
  n_cols = rmatrix.get_n_cols();
  matrix = new T[n_rows*n_cols];
  for (unsigned i=0; i<n_rows*n_cols; ++i)
  {
    matrix[i] = rmatrix.matrix[i];
  }
}

template<typename T>
Simple_Matrix<T>::Simple_Matrix(unsigned _n_rows, unsigned _n_cols, const T _init_array[])
{
  n_rows = _n_rows;
  n_cols = _n_cols;
  matrix = new T[n_rows*n_cols];
  for (unsigned i=0; i<n_rows*n_cols; ++i)
  {
    matrix[i] = _init_array[i];
  }
}

template<typename T>
Simple_Matrix<T>& Simple_Matrix<T>::operator=(const Simple_Matrix<T>& rmatrix)
{
  if(&rmatrix == this) return *this;

  unsigned n_rows = rmatrix.get_n_rows();
  unsigned n_cols = rmatrix.get_n_cols();

  delete [] matrix;
  matrix = new T[n_rows*n_cols];
  for (unsigned i=0; i<n_rows*n_cols; ++i)
  {
    matrix[i] = rmatrix.matrix[i];
  }

  return *this;
}

template<typename T>
Simple_Matrix<T>::~Simple_Matrix()
{
  delete [] matrix;
}

template<typename T>
Simple_Matrix<T> Simple_Matrix<T>::operator*(const Simple_Matrix<T>& rmatrix)
{
  unsigned _n_rows = rmatrix.get_n_rows();
  unsigned _n_cols = rmatrix.get_n_cols();
  if(n_rows != _n_cols || n_cols != _n_rows)
  {
    std::cerr << "Error: Wrong Matrices size for Multiplication!!\n";
    std::exit(1);
  }
  Simple_Matrix<T> result(n_rows, n_rows, 0.0);

#pragma omp target teams distribute parallel for collapse(3)
  for (unsigned i=0; i < n_rows; i++)
  {
    for (unsigned j=0; j < n_rows; j++)
    {
      for (unsigned k=0; k < n_cols; k++)
      {
        result(i,j) += this->matrix[i*n_cols+k] * rmatrix(k,j);
//        result.matrix[i*n_rows+j] += this->matrix[i*n_cols+k] * rmatrix.matrix[k*n_rows+j];
      }
    }
  }

  return result;
}
#pragma omp end declare target

#endif
