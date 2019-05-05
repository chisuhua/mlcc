#include "simple_matrix_dyn_array.h"

int main(void)
{
  Simple_Matrix<int> M1(5,7,10), M2(7,5,5), M(5,5,0);
  M = M1 * M2;

  std::cout << "M1:\n";
  M1.print();
  std::cout << "\n";
  std::cout << "M2:\n";
  M2.print();
  std::cout << "\n";
  std::cout << "M1*M2:\n";
  M.print();
  std::cout << "\n";

  int INIT_ARR[2*3]={1,2,3,4,5,6};
  Simple_Matrix<int> N1(2,3,10), N2(3,2,INIT_ARR), N(2,2,0);
  N = N1 * N2;

  std::cout << "N1:\n";
  N1.print();
  std::cout << "\n";
  std::cout << "N2:\n";
  N2.print();
  std::cout << "\n";
  std::cout << "N1*N2:\n";
  N.print();
  std::cout << "\n";

  return 0;
}
